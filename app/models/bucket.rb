class Bucket < ApplicationRecord
  belongs_to :drivers_day
  belongs_to :drop_off_event, optional: true

  # Driver puts a bucket (with compost) on the scale. We record the gross,
  # and auto-subtract tare before save so weight_kg is NET.
  TARE_25L_KG = 0.90
  TARE_45L_KG = 1.50

  # Virtual attribute to accept the scale reading
  attr_accessor :gross_kg

  before_validation :apply_tare

  validates :weight_kg,
            presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  # validates :half, inclusion: { in: [true, false] }

  # after_initialize { self.half = false if half.nil? }
  after_commit :recalc_day_cache, on: %i[create update destroy]

  private

  def apply_tare
    return if gross_kg.blank?

    # Use appropriate tare weight based on bucket size
    tare = case bucket_size
           when 45
             TARE_45L_KG
           else
             TARE_25L_KG  # Default for 25L or nil
           end

    net = gross_kg.to_f - tare
    self.weight_kg = [[net, 0].max, 99.999].min.round(3)
  end

  def recalc_day_cache
    dd = drivers_day
    dd.update_columns(
      total_net_kg: dd.buckets.sum(:weight_kg),
      total_buckets: dd.buckets.count, # keep in sync with physical bucket count
      updated_at: Time.current
    )
  end
end
