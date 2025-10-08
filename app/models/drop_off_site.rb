class DropOffSite < ApplicationRecord
  has_many :drop_off_events, dependent: :nullify

  # Geocoding
  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?

  # Validations
  validates :name, presence: true
  validates :street_address, presence: true
  validates :suburb, inclusion: { in: Subscription::SUBURBS }
  validates :collection_day, presence: true

  # Enum for collection day
  enum :collection_day, Date::DAYNAMES


  # Methods
  def total_events
    drop_off_events.count
  end

  def events_this_week
    drop_off_events.where(date: Date.today.beginning_of_week..Date.today.end_of_week)
  end

  def recalc_totals!
    update!(
      total_weight_kg: drop_off_events.sum(:weight_kg),
      total_dropoffs_count: drop_off_events.where(is_done: true).count
    )
  end

end
  