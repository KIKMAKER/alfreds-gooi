class DropOffSite < ApplicationRecord
  has_many :drop_off_events, dependent: :nullify
  belongs_to :user, optional: true
  has_one_attached :photo

  # Geocoding
  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?

  # Slug generation
  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_name? }

  # Validations
  validates :name, presence: true
  validates :street_address, presence: true
  validates :suburb, inclusion: { in: Subscription::SUBURBS }
  validates :collection_day, presence: true
  validates :slug, presence: true, uniqueness: true

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

  # Override to_param to use slug in URLs
  def to_param
    slug
  end

  # Class method to get suburbs for a given collection day
  def self.suburbs_for_day(day)
    case day.to_s.capitalize
    when "Tuesday"
      Subscription::TUESDAY_SUBURBS
    when "Wednesday"
      Subscription::WEDNESDAY_SUBURBS
    when "Thursday"
      Subscription::THURSDAY_SUBURBS
    else
      []
    end
  end

  # Instance method to get suburbs served by this drop-off site
  def served_suburbs
    self.class.suburbs_for_day(collection_day)
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end

end
