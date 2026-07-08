module RevenueRecognitions
  # Bulk-creates recognition rows for invoices that have none.
  #
  #   RevenueRecognitions::Backfill.new(dry_run: true).call   # plan only
  #   RevenueRecognitions::Backfill.new(dry_run: false).call  # write
  #
  # Idempotent: only invoices with zero recognition rows are touched unless
  # force: true, which deletes-and-recreates rows for every invoice in scope
  # (optionally narrowed with invoice_ids:).
  #
  # Returns an array of RevenueRecognitions::Recognize::Result.
  class Backfill
    def initialize(dry_run: true, force: false, invoice_ids: nil)
      @dry_run = dry_run
      @force = force
      @invoice_ids = invoice_ids
    end

    def call
      results = []
      invoice_scope.find_each do |invoice|
        recognizer = Recognize.new(invoice)
        results << (@dry_run ? recognizer.plan : recognizer.call(force: @force))
      rescue StandardError => e
        results << Recognize::Result.new(invoice: invoice, status: :exception, rows: [],
                                         reason: "error: #{e.message}")
      end
      results
    end

    # Months touched by written rows — used to recompute financial_metrics.
    def self.affected_months(results)
      results.select(&:written?).flat_map(&:months).uniq.sort
    end

    private

    def invoice_scope
      scope = Invoice.includes(:subscription, order: :collection).order(:issued_date, :id)
      scope = scope.where(id: @invoice_ids) if @invoice_ids
      scope = scope.where.missing(:revenue_recognitions) unless @force
      scope
    end
  end
end
