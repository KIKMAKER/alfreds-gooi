module RevenueRecognitions
  # Plans and writes revenue_recognitions rows for a single invoice.
  #
  # Recognition basis is accrual on issued_date — rows are created whether or
  # not the invoice is paid (cash collection is tracked separately via
  # invoice aging).
  #
  # Rules:
  # - order-linked invoices: full amount in the month of the linked
  #   collection's date (falling back to issue month), type 'one_off'
  # - once_off plan subscriptions: full amount in the month of the first
  #   collection (falling back to issue month), type 'one_off'
  # - monthly_invoicing subscriptions: full amount in the issue month
  # - term subscriptions (1/3/6/12 months): one-off items (starter kits,
  #   compost bags, soil) recognised fully in the issue month; the remaining
  #   service portion spread evenly across `duration` months with the
  #   rounding remainder on the final month
  #
  # Invoices with no resolvable subscription or order are returned as
  # :exception results and never written.
  class Recognize
    ONE_OFF_TITLES = /starter kit|starter bucket|once-off collection|compost bin bags|soil for life/i

    Row = Struct.new(:period_start, :period_end, :recognized_amount, :recognition_type, keyword_init: true)

    Result = Struct.new(:invoice, :status, :rows, :reason, keyword_init: true) do
      def planned?  = status == :planned
      def written?  = status == :written
      def exception? = status == :exception
      def total     = rows.sum(&:recognized_amount)
      def months    = rows.map { |r| [r.period_start.year, r.period_start.month] }.uniq
    end

    def initialize(invoice)
      @invoice = invoice
    end

    # Computes the recognition schedule without writing anything.
    def plan
      reason = unplannable_reason
      return Result.new(invoice: @invoice, status: :exception, rows: [], reason: reason) if reason

      Result.new(invoice: @invoice, status: :planned, rows: build_rows)
    end

    # Writes the schedule. Skips invoices that already have rows unless
    # force: true, which deletes and recreates them inside a row lock.
    def call(force: false)
      result = plan
      return result if result.exception?

      @invoice.with_lock do
        if @invoice.revenue_recognitions.exists?
          unless force
            return Result.new(invoice: @invoice, status: :skipped_existing, rows: [],
                              reason: "already has recognition rows")
          end
          @invoice.revenue_recognitions.delete_all
        end

        result.rows.each do |row|
          @invoice.revenue_recognitions.create!(
            subscription_id: @invoice.subscription_id,
            period_start: row.period_start,
            period_end: row.period_end,
            period_month: row.period_start.month,
            period_year: row.period_start.year,
            recognized_amount: row.recognized_amount,
            recognition_type: row.recognition_type
          )
        end

        verify_sum!
      end

      result.status = :written
      result
    end

    private

    def unplannable_reason
      return "missing issued_date" unless @invoice.issued_date
      return "missing total_amount" if @invoice.total_amount.nil?
      return "negative total_amount (#{@invoice.total_amount})" if @invoice.total_amount.negative?

      sub = @invoice.subscription
      return nil if @invoice.order_id.present?

      if sub.nil?
        if @invoice.legacy_subscription_id.present?
          return "only legacy_subscription_id=#{@invoice.legacy_subscription_id}, no live subscription"
        end
        return "no subscription or order attached"
      end

      if !sub.once_off? && !sub.monthly_invoicing? && (sub.duration.nil? || sub.duration < 1)
        return "subscription ##{sub.id} (#{sub.plan}) has no usable duration"
      end

      nil
    end

    def build_rows
      total = round2(@invoice.total_amount)
      return [single_row(@invoice.issued_date, "service", amount: 0.0)] if total.zero?

      if @invoice.order_id.present?
        date = @invoice.order&.collection&.date || @invoice.issued_date
        return [single_row(date, "one_off", amount: total)]
      end

      sub = @invoice.subscription
      if sub.once_off?
        date = sub.collections.minimum(:date) || @invoice.issued_date
        return [single_row(date, "one_off", amount: total)]
      end

      return [single_row(@invoice.issued_date, "service", amount: total)] if sub.monthly_invoicing?

      spread_rows(sub, total)
    end

    def spread_rows(sub, total)
      one_off_total = round2(one_off_items_total)
      service_total = round2(total - one_off_total)

      rows = []
      if one_off_total.positive? && service_total >= 0
        rows << single_row(@invoice.issued_date, "one_off", amount: one_off_total)
        return rows if service_total.zero?
      else
        # Item data can't support a reliable split (e.g. discounts exceed the
        # service portion) — spread the whole invoice instead.
        service_total = total
      end

      start = service_start_date(sub)
      amounts = split_cents(service_total, sub.duration)
      sub.duration.times do |i|
        period_start = i.zero? ? start : (start.beginning_of_month + i.months)
        rows << Row.new(
          period_start: period_start,
          period_end: period_start.end_of_month,
          recognized_amount: amounts[i],
          recognition_type: "service"
        )
      end
      rows
    end

    # Prefer the subscription's actual service window when it plausibly
    # matches this invoice (start_date within the issue month or the
    # following 60 days — true for first invoices paid just before service
    # begins). Renewal invoices issued long after start_date fall back to
    # the issue month.
    def service_start_date(sub)
      issued = @invoice.issued_date.to_date
      start = sub.start_date&.to_date
      if start && start >= issued.beginning_of_month && start <= issued + 60
        start
      else
        issued
      end
    end

    def one_off_items_total
      @invoice.invoice_items.includes(:product).sum do |item|
        next 0.0 unless item.product&.title&.match?(ONE_OFF_TITLES)

        (item.amount || 0) * (item.quantity || 0)
      end
    end

    def single_row(date, type, amount:)
      date = date.to_date
      Row.new(period_start: date, period_end: date.end_of_month,
              recognized_amount: amount, recognition_type: type)
    end

    # Exact split in integer cents: base amount per month, remainder cents on
    # the final month, so rows always sum to the total.
    def split_cents(amount, parts)
      cents = (amount * 100).round
      base = cents / parts
      remainder = cents - base * parts
      amounts = Array.new(parts, base / 100.0)
      amounts[-1] = (base + remainder) / 100.0
      amounts
    end

    def verify_sum!
      recognized = @invoice.revenue_recognitions.sum(:recognized_amount).to_f
      diff = (recognized - @invoice.total_amount.to_f).abs
      return if diff <= 0.01

      raise "Revenue recognition mismatch for invoice ##{@invoice.id}: " \
            "recognized R#{recognized} vs invoice total R#{@invoice.total_amount}"
    end

    def round2(value)
      value.to_f.round(2)
    end
  end
end
