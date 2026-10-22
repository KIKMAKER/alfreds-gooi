class FestivalWasteLog < ApplicationRecord
  ORGANIC_CATEGORY   = "organic"
  CHANEL_CATEGORIES  = %w[plastic glass tin paper landfill].freeze
  ALL_CATEGORIES     = ([ORGANIC_CATEGORY] + CHANEL_CATEGORIES).freeze

  CATEGORY_LABELS = {
    "organic"  => "Organics",
    "plastic"  => "Plastic",
    "glass"    => "Glass",
    "tin"      => "Tin",
    "paper"    => "Paper",
    "landfill" => "Landfill"
  }.freeze

  # Rigid containers are tared the same way as Bucket (weight_kg is NET).
  # A blank container means no tare, e.g. loose bags or an already-net figure.
  CONTAINER_TARES = {
    25 => Bucket::TARE_25L_KG,
    45 => Bucket::TARE_45L_KG,
    80 => Bucket::TARE_80L_KG
  }.freeze

  # Nullable enums — only set on organic entries
  enum :source,      { attendee: 0, vendor: 1 },      prefix: true, allow_nil: true
  enum :destination, { compost: 0, pigs: 1 },         prefix: true, allow_nil: true

  belongs_to :festival_event
  belongs_to :festival_participant, optional: true

  before_validation :apply_tare

  validates :container_size, inclusion: { in: CONTAINER_TARES.keys }, allow_nil: true
  validates :day_number, :logged_at, :category, :weight_kg, presence: true
  validates :category, inclusion: { in: ALL_CATEGORIES }
  validates :weight_kg, numericality: { greater_than: 0 }

  scope :organic, -> { where(category: ORGANIC_CATEGORY) }
  scope :inorganic, -> { where(category: CHANEL_CATEGORIES) }
  scope :for_day, ->(n) { where(day_number: n) }

  def organic?
    category == ORGANIC_CATEGORY
  end

  def category_label
    CATEGORY_LABELS[category] || category.humanize
  end

  def organic_label
    return nil unless organic?
    src  = source&.humanize      || "N/A"
    dest = destination&.humanize || "N/A"
    "#{src} → #{dest}"
  end

  def tare_kg
    CONTAINER_TARES.fetch(container_size, 0)
  end

  private

  # Scale reading in, net out. Entries without gross_kg (older queued
  # submissions) keep whatever weight_kg they were given.
  def apply_tare
    return if gross_kg.blank?

    self.weight_kg = [gross_kg.to_f - tare_kg, 0].max.round(3)
  end
end
