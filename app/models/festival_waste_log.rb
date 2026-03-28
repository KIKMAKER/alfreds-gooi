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

  # Nullable enums — only set on organic entries
  enum :source,      { attendee: 0, vendor: 1 },      prefix: true, allow_nil: true
  enum :destination, { compost: 0, pigs: 1 },         prefix: true, allow_nil: true

  belongs_to :festival_event
  belongs_to :festival_participant, optional: true

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

  def team
    organic? ? "Gooi" : "Chanel"
  end

  def organic_label
    return nil unless organic?
    src  = source&.humanize      || "N/A"
    dest = destination&.humanize || "N/A"
    "#{src} → #{dest}"
  end
end
