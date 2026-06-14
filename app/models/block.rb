class Block < ApplicationRecord
  has_many :subscriptions, dependent: :nullify
  has_many :block_survey_responses, dependent: :destroy
  has_many :quotations, dependent: :nullify
  has_many_attached :photos

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :resident_count, numericality: { greater_than: 0, allow_nil: true }

  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  # ── Physical constants ──────────────────────────────────────────────────────
  # Assumed kitchen scrap volume per participating household per week.
  # Used to back-calculate an estimated number of contributing households
  # from the collection volume without needing individual household sign-ups.
  LITRES_PER_HOUSEHOLD = 5

  # Kitchen scraps density: ~0.6 kg per litre (conservative estimate)
  DENSITY_KG_PER_L = 0.6

  # CO₂ equivalent avoidance per kg food waste diverted from landfill
  # (methane avoidance basis — IPCC figures)
  CO2E_PER_KG = 1.9

  # ── Address derived from subscriptions ──────────────────────────────────────
  # The block's physical address is the same as the subscriptions at that building.
  # We derive it from the linked subscriptions rather than storing it separately.

  # Primary suburb (from the most common suburb among linked subscriptions, or the first one).
  def suburb
    return nil if subscriptions.none?
    subscriptions.group(:suburb).order("count_all DESC").count.first&.first
  end

  # A human-readable display address: prefer the first subscription's street address
  # plus the canonical suburb. Falls back to just the suburb.
  def derived_address
    first_sub = subscriptions.order(:created_at).first
    return nil unless first_sub
    [first_sub.street_address, first_sub.suburb].compact.join(", ")
  end

  # ── Scopes ──────────────────────────────────────────────────────────────────
  def active_subscriptions
    subscriptions.where(status: :active)
  end

  # Unique collection days (as day-name strings, e.g. ["Tuesday"]) derived
  # from active subscriptions. A block could theoretically span two routes.
  def collection_days
    active_subscriptions.distinct.pluck(:collection_day).compact
  end

  # Human-readable collection day string for display.
  # "every Tuesday"  /  "every Tuesday and Wednesday"
  def collection_days_label
    days = collection_days
    return nil if days.empty?
    "every #{days.to_sentence}"
  end

  # ── Expected stats ──────────────────────────────────────────────────────────

  # How much we'd expect to collect this week if all active subscriptions
  # put out their full allocation. Delegates to each sub's own configuration:
  # Commercial → buckets_per_collection × bucket_size × collections_per_week
  # XL         → 25L × collections_per_week
  # Standard   → 5L  × collections_per_week (per bag; adjust if bag count tracked)
  def expected_weekly_volume_l
    active_subscriptions.sum(&:expected_weekly_volume_l)
  end

  # ── Actual stats ─────────────────────────────────────────────────────────────

  # All non-skipped collections for this block within a date range,
  # with their subscriptions eager-loaded for volume_litres calculations.
  def collections_in_range(date_range)
    Collection
      .joins(:subscription)
      .where(subscriptions: { block_id: id })
      .where(date: date_range, skip: false)
      .includes(:subscription)
  end

  def actual_volume_l(date_range)
    collections_in_range(date_range).sum(&:volume_litres)
  end

  # Convenience methods for common time windows
  def actual_volume_this_week_l
    actual_volume_l(Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def actual_volume_this_month_l
    actual_volume_l(Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def lifetime_volume_l
    # Endless range → no upper date bound, so future-dated pre-scheduled
    # collections (e.g. next Tuesday's route) are included correctly.
    actual_volume_l(Date.new(2000)..)
  end

  # ── Weight & climate stats ───────────────────────────────────────────────────

  def weight_kg(volume_l)
    (volume_l * DENSITY_KG_PER_L).round(1)
  end

  def co2e_kg(volume_l)
    (weight_kg(volume_l) * CO2E_PER_KG).round(1)
  end

  # ── Household estimates ──────────────────────────────────────────────────────

  def active_subscription_count
    active_subscriptions.count
  end

  # Estimated households contributing, derived from the average volume
  # per collection (lifetime actual ÷ number of collections) rather than
  # contracted capacity. This reflects real participation, not maximum possible.
  # e.g. 1 collection × 90L → avg 90L → 90 ÷ 5L = ~18 households
  # Over time the average stabilises as more data accumulates.
  def estimated_contributing_households
    total_collections = collections_in_range(Date.new(2000)..).count
    return nil if total_collections.zero?
    avg_l_per_collection = lifetime_volume_l.to_f / total_collections
    (avg_l_per_collection / LITRES_PER_HOUSEHOLD).ceil
  end

  # ── Per-household projected annual impact (used on survey page) ─────────────

  WEEKS_PER_YEAR = 52

  def self.annual_kg_per_household
    (LITRES_PER_HOUSEHOLD * WEEKS_PER_YEAR * DENSITY_KG_PER_L).round
  end

  def self.annual_co2e_per_household
    (annual_kg_per_household * CO2E_PER_KG).round
  end

  # ── Survey aggregates ────────────────────────────────────────────────────────

  def survey_response_count
    block_survey_responses.count
  end

  def survey_wants_phase_one_count
    block_survey_responses.where(wants_phase_one: true).count
  end

  def survey_wants_bin_count
    block_survey_responses.where(wants_to_buy_bin: true).count
  end

  def survey_has_bin_count
    block_survey_responses.where(has_compost_bin: true).count
  end

  # ── Slug generation ──────────────────────────────────────────────────────────

  private

  def generate_slug
    base = name.to_s.downcase.gsub(/[^a-z0-9\s\-]/, "").gsub(/\s+/, "-").strip
    candidate = base
    n = 1
    while Block.exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end
