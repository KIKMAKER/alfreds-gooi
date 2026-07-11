class DropOffEvent < ApplicationRecord
  belongs_to :drop_off_site
  belongs_to :drivers_day
  has_many :buckets, dependent: :nullify
  acts_as_list scope: :drivers_day

  # Suffixed to match Subscription — a single route day can drop general waste at
  # one site and protein at another, so kilograms stay separable by stream.
  enum :waste_stream, %i[general protein], suffix: true

  # Scopes
  scope :recent, -> { order(date: :desc) }
  scope :protein, -> { where(waste_stream: :protein) }
  scope :general, -> { where(waste_stream: :general) }
  scope :completed, -> { where(is_done: true) }

  validate :protein_only_at_protein_capable_sites

  # Methods
  def done?
    is_done
  end

  def today?
    date == Date.current
  end

  # Calculate total weight from all buckets weighed at this drop-off
  def total_weight_from_buckets
    buckets.loaded? ? buckets.sum(&:weight_kg) : buckets.sum(:weight_kg)
  end

  # Calculate average weight per bucket at this drop-off
  def avg_weight_per_bucket
    n = buckets.loaded? ? buckets.size : buckets.count
    return 0.0 if n.zero?
    total_weight_from_buckets / n
  end

  # Full-equivalent count normalized to 25L buckets
  # A 45L bucket = 1.8 equivalent 25L buckets (45/25)
  def full_equivalent_count
    buckets.sum do |bucket|
      size_multiplier = (bucket.bucket_size || 25).to_f / 25.0
      half_multiplier = bucket.half? ? 0.5 : 1.0
      size_multiplier * half_multiplier
    end
  end

  # Average weight per full-equivalent bucket
  def avg_weight_per_full_equiv
    denom = full_equivalent_count.to_f
    return 0.0 if denom <= 0
    total_weight_from_buckets / denom
  end

  # Count buckets by size
  def bucket_count_25l
    buckets.loaded? ? buckets.count { |b| b.bucket_size == 25 } : buckets.where(bucket_size: 25).count
  end

  def bucket_count_45l
    buckets.loaded? ? buckets.count { |b| b.bucket_size == 45 } : buckets.where(bucket_size: 45).count
  end

  # Timing methods for drop-off duration tracking
  def calculate_duration
    return unless arrival_time && departure_time
    self.duration_minutes = ((departure_time - arrival_time) / 60).round
  end

  def in_progress?
    arrival_time.present? && departure_time.blank?
  end

  def timing_complete?
    arrival_time.present? && departure_time.present?
  end

  def duration_display
    return "—" unless duration_minutes
    hours = duration_minutes / 60
    mins = duration_minutes % 60
    hours > 0 ? "#{hours}h #{mins}m" : "#{mins}m"
  end

  # After completing drop-off, recalculate site totals and send email
  after_update :recalc_site_totals, if: -> { saved_change_to_is_done? || saved_change_to_weight_kg? }
  after_update :send_completion_email, if: -> { saved_change_to_is_done? && is_done? }

  # Timing callbacks
  before_save :calculate_duration, if: -> { departure_time_changed? }
  after_save :update_site_analytics, if: -> { saved_change_to_departure_time? && timing_complete? }

  private

  def protein_only_at_protein_capable_sites
    return unless protein_waste_stream?
    return if drop_off_site&.accepts_protein?

    errors.add(:waste_stream, "cannot be protein — #{drop_off_site&.name || 'this site'} does not accept protein")
  end

  def recalc_site_totals
    drop_off_site.recalc_totals!
  end

  def send_completion_email
    return unless drop_off_site.user.present?
    DropOffEventMailer.completion_notification(self).deliver_now
  end

  def update_site_analytics
    drop_off_site.recalculate_average_duration
  end
end
