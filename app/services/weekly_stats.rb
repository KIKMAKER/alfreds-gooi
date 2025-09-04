# frozen_string_literal: true
class WeeklyStats
  # Buckets are 25L each
  LITRES_PER_BUCKET = 25.0

  Result = Struct.new(
    :period_label, :start_date, :end_date,
    :customers_served, :buckets_diverted, :litres_diverted,
    :skips, :new_customers, :route_kms, :soil_bags
  )

  # mode: :route_week anchors to Tue–Thu of the given week
  # anchor_date: typically the DriversDay#date for Thursday
  def self.call(start_date: nil, end_date: nil, anchor_date: nil, mode: :default, timezone: "Africa/Johannesburg")
    tz = ActiveSupport::TimeZone.new(timezone)

    if mode == :route_week
      raise ArgumentError, "anchor_date required for :route_week" unless anchor_date
      # Week starts Monday; route is Tue..Thu
      week_start = anchor_date.beginning_of_week(:monday) + 1.day   # Tuesday
      week_end   = week_start + 2.days                              # Thursday
      start_date ||= week_start
      end_date   ||= week_end
    else
      today = tz.today
      end_date   ||= today
      start_date ||= end_date - 6.days
    end

    cols = Collection.where(date: start_date..end_date)
    days = DriversDay.where(date: start_date..end_date)

    served_ids       = cols.where(skip: false).distinct.pluck(:subscription_id)
    customers_served = served_ids.count
    buckets_diverted = days.sum(:total_buckets).to_f
    litres_diverted  = (buckets_diverted * LITRES_PER_BUCKET).round(0)

    skips         = cols.where(skip: true).count
    new_customers = cols.where(new_customer: true).distinct.count(:subscription_id)
    # soil_bags     = cols.sum(:soil_bag).to_i
    route_kms     = days.sum do |d|
      ((d.end_kms || 0) - (d.start_kms || 0)).clamp(0, 1_000_000)
    end

    period_label = "#{start_date.strftime('%d %b')}–#{end_date.strftime('%d %b %Y')}"

    Result.new(
      period_label, start_date, end_date,
      customers_served, buckets_diverted, litres_diverted,
      skips, new_customers, route_kms
    )
    # soil_bags,
  end
end
