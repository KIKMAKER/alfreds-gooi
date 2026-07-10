class DriversDay < ApplicationRecord
  belongs_to :user
  has_many :collections, dependent: :nullify
  has_many :drop_off_events, dependent: :nullify
  has_many :buckets, dependent: :destroy
  has_one :day_statistic, dependent: :destroy
  belongs_to :current_drop_off_event, class_name: 'DropOffEvent', optional: true

  scope :with_end_time, -> { where.not(end_time: nil) }
  scope :this_year,    ->(year) { where("EXTRACT(year FROM date) = ?", year) }

  scope :with_active_collection_counts, -> {
    left_joins(:collections)
      .where("collections.skip = false OR collections.id IS NULL")
      .select("drivers_days.*, COUNT(collections.id) AS active_collection_count")
      .group("drivers_days.id")
  }

  # A route longer than this many hours almost always means the End tap was
  # missed on the day and pressed later — see end_time_flag / end_time_sensible.
  MAX_ROUTE_HOURS = 12

  # A route shorter than this many minutes almost always means the Start tap was
  # missed in the morning and pressed at wrap-up (start ≈ end in the afternoon).
  MIN_ROUTE_MINUTES = 15

  # Set true to consciously accept a genuinely long / cross-midnight day and skip
  # the end_time sanity check (e.g. Alfred confirms "yes, it really was that long").
  attr_accessor :override_end_time_warning

    # validations
  validates :total_buckets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :end_time_sensible,
           if: -> { end_time.present? && start_time.present? && !override_end_time_warning }

  # Set a default if total_buckets is nil
  before_validation :set_default_buckets

  # create weekly stats report if its' thursday
  after_commit :send_weekly_stats_if_thursday_finished,
               if: -> { saved_change_to_end_time? && end_time.present? }

  # recalculate stats when kms or times are updated
  after_commit :recalculate_statistics,
               if: -> { (saved_change_to_start_kms? || saved_change_to_end_kms? || saved_change_to_start_time? || saved_change_to_end_time?) && day_statistic.present? }


  # custom methods

  def self.new_customer_count_for(collections)
    subscription_ids = collections.where.not(subscription_id: nil).pluck(:subscription_id).uniq
    user_ids = Subscription.where(id: subscription_ids).pluck(:user_id).uniq
    Collection.joins(:subscription)
              .where(subscriptions: { user_id: user_ids })
              .where(date: ..Date.today)
              .group("subscriptions.user_id")
              .count
              .count { |_, total| total == 1 }
  end

  def note_nil_zero?
    note.nil? || note == ""
  end

  # Classifies a suspicious start/end pairing so the End view can explain the
  # exact problem to Alfred. Returns nil when the pair looks fine.
  #   :inverted      -> end is before start
  #   :too_short     -> less than MIN_ROUTE_MINUTES long (Start tap likely missed)
  #   :too_long      -> more than MAX_ROUTE_HOURS after start
  #   :different_day -> lands on a different calendar day to the start
  def end_time_flag
    return nil unless end_time && start_time

    if end_time < start_time
      :inverted
    elsif (end_time - start_time) < MIN_ROUTE_MINUTES.minutes
      :too_short
    elsif (end_time - start_time) > MAX_ROUTE_HOURS.hours
      :too_long
    elsif end_time.to_date != start_time.to_date
      :different_day
    end
  end

  # The field most likely to be wrong for a given flag — drives which correction
  # input the End view shows. A too_short day means the *start* was tapped late.
  def end_time_flag_field
    end_time_flag == :too_short ? :start_time : :end_time
  end

  # Set the current drop-off being worked on
  def set_current_drop_off(drop_off_event)
    update(current_drop_off_event: drop_off_event)
  end

  # Calculate total time spent at drop-offs for this day
  def total_dropoff_duration_minutes
    if drop_off_events.loaded?
      drop_off_events.sum { |e| e.duration_minutes.to_i }
    else
      drop_off_events.where.not(duration_minutes: nil).sum(:duration_minutes)
    end
  end

  # Human-readable total drop-off duration
  def total_dropoff_duration_display
    total_mins = total_dropoff_duration_minutes
    return "—" if total_mins.zero?

    hours = total_mins / 60
    mins = total_mins % 60
    hours > 0 ? "#{hours}h #{mins}m" : "#{mins}m"
  end

  # Calculate total litres from all buckets
  def total_litres
    total = 0.0
    buckets.each do |bucket|
      size = bucket.bucket_size || 25
      multiplier = bucket.half? ? 0.5 : 1.0
      total += size * multiplier
    end
    total
  end

  def recalc_totals!
    update!(
      total_net_kg: buckets.sum(:weight_kg),
      total_buckets: buckets.count
    )
  end

  # Full-equivalent count normalized to 25L buckets
  # A 45L bucket = 1.8 equivalent 25L buckets (45/25)
  def full_equivalent_count
    total = 0.0
    buckets.each do |bucket|
      size_multiplier = (bucket.bucket_size || 25).to_f / 25.0  # Normalize to 25L
      half_multiplier = bucket.half? ? 0.5 : 1.0
      total += size_multiplier * half_multiplier
    end
    total
  end

  # Average weight per bucket
  def avg_net_kg_per_bucket
    return 0.0 if buckets.count.zero?
    total_net_kg.to_f / buckets.count
  end

  # Average weight per full-equivalent 25L bucket
  def avg_net_kg_per_full_equiv
    equiv = full_equivalent_count.to_f
    return 0.0 if equiv <= 0
    total_net_kg.to_f / equiv
  end

  def products_needed_for_delivery
    # Find all orders attached to today's collections
    orders = Order.where(collection_id: collections.pluck(:id), status: [:pending, :paid])
                  .includes(:order_items)

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

  def recalculate_statistics
    calculate_and_save_statistics!
  end

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

  # Rejects a start/end pairing that can't be right for a single day's route,
  # prompting Alfred to correct it in the moment (or tick "override" for a
  # genuine outlier). The error attaches to whichever field is likely wrong.
  def end_time_sensible
    case end_time_flag
    when :inverted
      errors.add(:end_time, "can't be before the start time (#{start_time.strftime('%H:%M')}). Set the real time you finished.")
    when :too_short
      mins = ((end_time - start_time) / 60.0).round
      errors.add(:start_time, "is only #{mins} min before the end — looks like the Start tap was missed this morning. Set the real time you started, or tick the box if it really was that quick.")
    when :too_long
      hours = ((end_time - start_time) / 3600.0).round(1)
      errors.add(:end_time, "is #{hours} hours after the start — looks like the End tap was missed. Set the real finish time, or tick the box if the day really was that long.")
    when :different_day
      errors.add(:end_time, "is on a different day (#{end_time.strftime('%a %-d %b')}) to the start (#{start_time.strftime('%a %-d %b')}). Set the real finish time, or tick the box to confirm.")
    end
  end
end
