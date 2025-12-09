class DropOffEvent < ApplicationRecord
  belongs_to :drop_off_site
  belongs_to :drivers_day, optional: true
  has_many :buckets, dependent: :nullify
  acts_as_list scope: :drivers_day

  # Scopes
  scope :recent, -> { order(date: :desc) }

  # Methods
  def done?
    is_done
  end

  def today?
    date == Date.current
  end

  # Calculate total weight from all buckets weighed at this drop-off
  def total_weight_from_buckets
    buckets.sum(:weight_kg)
  end

  # Calculate average weight per bucket at this drop-off
  def avg_weight_per_bucket
    return 0.0 if buckets.count.zero?
    total_weight_from_buckets / buckets.count
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

  # Average weight per full-equivalent bucket
  def avg_weight_per_full_equiv
    denom = full_equivalent_count.to_f
    return 0.0 if denom <= 0
    total_weight_from_buckets / denom
  end

  # Count buckets by size
  def bucket_count_25l
    buckets.where(bucket_size: 25).count
  end

  def bucket_count_45l
    buckets.where(bucket_size: 45).count
  end

  # After completing drop-off, recalculate site totals and send email
  after_update :recalc_site_totals, if: -> { saved_change_to_is_done? || saved_change_to_weight_kg? }
  after_update :send_completion_email, if: -> { saved_change_to_is_done? && is_done? }

  private

  def recalc_site_totals
    drop_off_site.recalc_totals!
  end

  def send_completion_email
    return unless drop_off_site.user.present?
    DropOffEventMailer.completion_notification(self).deliver_later
  end
end
