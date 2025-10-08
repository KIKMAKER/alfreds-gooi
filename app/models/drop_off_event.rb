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

  # Full-equivalent count using the half flag
  def full_equivalent_count
    full = buckets.where(half: false).count
    halves = buckets.where(half: true).count
    full + halves * 0.5
  end

  # Average weight per full-equivalent bucket
  def avg_weight_per_full_equiv
    denom = full_equivalent_count.to_f
    return 0.0 if denom <= 0
    total_weight_from_buckets / denom
  end

  # After completing drop-off, recalculate site totals
  after_update :recalc_site_totals, if: -> { saved_change_to_is_done? || saved_change_to_weight_kg? }

  private

  def recalc_site_totals
    drop_off_site.recalc_totals!
  end
end
