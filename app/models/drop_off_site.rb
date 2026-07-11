class DropOffSite < ApplicationRecord
  has_many :drop_off_events, dependent: :nullify
  belongs_to :user, optional: true
  has_one_attached :photo

  # Geocoding
  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?

  # Slug generation
  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_name? }

  # Sites can sit in suburbs Gooi doesn't collect from — Langa hosts the AgriHub
  # BioBin but has no collection round, so it is not a customer-selectable suburb.
  DROP_OFF_ONLY_SUBURBS = ["Langa", "Philippi", "Epping"].freeze
  SUBURBS = (Subscription::SUBURBS + DROP_OFF_ONLY_SUBURBS).sort.freeze

  # Validations
  validates :name, presence: true
  validates :street_address, presence: true
  validates :suburb, inclusion: { in: SUBURBS }
  validates :collection_day, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :fee_per_kg, numericality: { greater_than_or_equal_to: 0 }

  # Enum for collection day
  enum :collection_day, Date::DAYNAMES

  # Scopes
  scope :protein_capable, -> { where(accepts_protein: true) }
  # Sites that bill us for disposal. Free sites (Soil for Life) sit at 0.
  scope :charging,        -> { where("fee_per_kg > 0") }

  # Disposal fees owed to this site for a calendar month: completed drop-offs
  # only, weighed against the kilograms the driver recorded on the event.
  def fees_for(year:, month:)
    period = Date.new(year, month, 1)..Date.new(year, month, 1).end_of_month
    kg = drop_off_events.where(is_done: true, date: period).sum(:weight_kg).to_f.round(2)

    { kg: kg, fee: (kg * fee_per_kg.to_f).round(2) }
  end

  def charges_disposal_fee?
    fee_per_kg.to_f.positive?
  end

  # Which stream a new drop-off at this site should start on. A protein-capable
  # site (Langa AgriHub's in-vessel BioBin) exists to take protein, so default
  # there; the driver can still switch a drop back to general on the event.
  def default_waste_stream
    accepts_protein? ? "protein" : "general"
  end

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

  # Recalculate average duration from all completed drop-offs
  def recalculate_average_duration
    events = drop_off_events.where.not(duration_minutes: nil)

    if events.any?
      self.completed_dropoffs_count = events.count
      self.total_duration_minutes = events.sum(:duration_minutes)
      self.average_duration_minutes = (total_duration_minutes.to_f / completed_dropoffs_count).round(1)
      save
    end
  end

  # Override to_param to use slug in URLs
  def to_param
    slug.presence || id.to_s
  end

  # Class method to get suburbs for a given collection day
  def self.suburbs_for_day(day)
    case day.to_s.capitalize
      when "Monday"
      Subscription::MONDAY_SUBURBS
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
