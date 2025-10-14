class DriversDay < ApplicationRecord
  belongs_to :user
  has_many :collections, dependent: :nullify
  has_many :drop_off_events, dependent: :nullify
  has_many :buckets, dependent: :destroy
  has_one :day_statistic, dependent: :destroy

    # validations
  validates :total_buckets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Set a default if total_buckets is nil
  before_validation :set_default_buckets

  # create weekly stats report if its' thursday
  after_commit :send_weekly_stats_if_thursday_finished,
               if: -> { saved_change_to_end_time? && end_time.present? }

  # custom methods

  def note_nil_zero?
    note.nil? || note == ""
  end

  def recalc_totals!
    update!(
      total_net_kg: buckets.sum(:weight_kg),
      total_buckets: buckets.count
    )
  end

  def products_needed_for_delivery
    # Find all orders attached to today's collections
    orders = Order.where(collection_id: collections.pluck(:id), status: [:pending, :paid])

    # Group order items by product and sum quantities
    product_summary = {}
    orders.each do |order|
      order.order_items.each do |item|
        product = item.product
        product_summary[product] ||= { quantity: 0, product: product }
        product_summary[product][:quantity] += item.quantity
      end
    end

    product_summary.values
  end

  def calculate_and_save_statistics!
    # Bucket stats
    bucket_records = buckets
    net_kg = bucket_records.sum(:weight_kg).to_f
    bucket_count = bucket_records.count
    half_count = bucket_records.where(half: true).count
    full_count = bucket_count - half_count
    full_equiv = full_count + (half_count * 0.5)

    # Collection stats
    households = collections.where(skip: false).where.not(updated_at: nil).count
    bags_sum = collections.where(skip: false).sum(:bags)

    # Route time stats
    route_hours = if start_time && end_time
                    ((end_time - start_time) / 3600.0)
                  end
    stops_per_hr = route_hours&.positive? ? (households / route_hours) : nil
    kg_per_hr = route_hours&.positive? ? (net_kg / route_hours) : nil

    # Distance stats
    kms = if start_kms && end_kms
            end_kms - start_kms
          end
    kg_per_km = (kms && kms > 0) ? (net_kg / kms) : nil

    # Environmental impact calculations
    waste_kg = net_kg
    kms_float = kms.to_f

    avoided = waste_kg * IMPACT[:co2e_per_kg_diverted]
    litres = (IMPACT[:l_per_100km] / 100.0) * kms_float
    driving = litres * IMPACT[:diesel_co2e_per_litre]
    net_co2e = avoided - driving

    trees_gross = avoided / IMPACT[:tree_co2e_per_year]
    trees_to_offset_drive = driving / IMPACT[:tree_co2e_per_year]
    trees_net = net_co2e / IMPACT[:tree_co2e_per_year]

    # Create or update the day_statistic record
    stat = day_statistic || build_day_statistic
    stat.update!(
      net_kg: net_kg,
      bucket_count: bucket_count,
      full_count: full_count,
      half_count: half_count,
      full_equiv: full_equiv,
      avg_kg_bucket: bucket_count.positive? ? (net_kg / bucket_count) : 0.0,
      avg_kg_full: full_equiv.positive? ? (net_kg / full_equiv) : 0.0,
      households: households,
      bags_sum: bags_sum,
      route_hours: route_hours,
      stops_per_hr: stops_per_hr,
      kg_per_hr: kg_per_hr,
      kms: kms,
      kg_per_km: kg_per_km,
      avoided_co2e_kg: avoided,
      driving_co2e_kg: driving,
      net_co2e_kg: net_co2e,
      trees_gross: trees_gross,
      trees_to_offset_drive: trees_to_offset_drive,
      trees_net: trees_net
    )

    stat
  end
  # def todays_driver
  #   DriversDay.where(date: Date.today)
  # end

  private

  def send_weekly_stats_if_thursday_finished
    # Ruby wday: 0=Sun ... 4=Thu
    return unless date&.wday == 4

    # Send synchronously so it lands as soon as Alfred finalises Thursday
    WeeklyStatsMailer.report(
      to: ENV.fetch("GOOI_STATS_EMAIL_TO", "kristen.c.kennedy@gmail.com"),
      anchor_date: date,
      mode: :route_week
    ).deliver_now

    # If you prefer a background hop (still immediate), swap to:
    # SendWeeklyStatsJob.perform_later(anchor_date: date)
  end

  def set_default_buckets
    self.total_buckets ||= 0
  end
end
