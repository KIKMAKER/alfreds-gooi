class DriversDay < ApplicationRecord
  belongs_to :user
  has_many :collections, dependent: :nullify
  has_many :buckets, dependent: :destroy

    # validations
  validates :total_buckets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Set a default if total_buckets is nil
  before_validation :set_default_buckets

  # create weekly stats report if its' thursday
  after_commit :send_weekly_stats_if_thursday_finished,
               if: -> { saved_change_to_end_time? && end_time.present? }

  # custom methods

  def hours_worked
    difference_in_seconds = end_time - start_time
    difference_in_hours = difference_in_seconds / 3600.0 # There are 3600 seconds in an hour
    format("%.2f hours", difference_in_hours)
  end

  def note_nil_zero?
    note.nil? || note == ""
  end

  def recalc_totals!
    update!(
      total_net_kg: buckets.sum(:weight_kg),
      total_buckets: buckets.count
    )
  end

  # “Full-equivalent” count using the half flag (no ratios beyond half)
  def full_equivalent_count
    full = buckets.where(half: false).count
    halves = buckets.where(half: true).count
    full + halves * 0.5
  end

  # Averages you may want to display
  def avg_net_kg_per_bucket
    return 0.0 if total_buckets.to_i.zero?
    (total_net_kg || 0).to_f / total_buckets.to_f
  end

  def avg_net_kg_per_full_equiv
    denom = full_equivalent_count.to_f
    return 0.0 if denom <= 0
    (total_net_kg || 0).to_f / denom
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
