class DropOffSite < ApplicationRecord
  has_many :drop_off_events, dependent: :nullify
  has_many :disposal_payments, dependent: :destroy
  belongs_to :user, optional: true
  belongs_to :suburb
  has_one_attached :photo
  # Signed letter from the facility confirming it composts what Gooi delivers and
  # how much it can take. Backs Gooi's City of Cape Town accreditation application.
  has_one_attached :facility_confirmation_letter

  # Geocoding
  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?

  # Slug generation
  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_name? }

  # Sites can sit in suburbs Gooi doesn't collect from — Langa hosts the AgriHub
  # BioBin but has no collection round, so it is not a customer-selectable suburb.
  # Fallback used when the suburbs table is missing or empty (fresh dev/CI boot).
  FALLBACK_DROP_OFF_ONLY_SUBURBS = ["Langa", "Philippi", "Epping"].freeze

  # DB-backed replacements for the old frozen DROP_OFF_ONLY_SUBURBS/SUBURBS
  # constants. See Subscription.SUBURBS for the same fallback pattern.
  def self.DROP_OFF_ONLY_SUBURBS
    return FALLBACK_DROP_OFF_ONLY_SUBURBS unless Suburb.table_exists?
    names = Suburb.drop_off_only.pluck(:name)
    names.empty? ? FALLBACK_DROP_OFF_ONLY_SUBURBS : names.sort
  end

  def self.SUBURBS
    (Subscription.SUBURBS + DROP_OFF_ONLY_SUBURBS()).sort
  end

  # Validations
  validates :name, presence: true
  validates :street_address, presence: true
  validates :collection_day, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :fee_per_kg, numericality: { greater_than_or_equal_to: 0 }
  validates :max_kg_per_delivery, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_deliveries_per_week, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 14 }, allow_nil: true
  validate  :acceptable_facility_letter

  # What the manager must fill in before a pre-filled facility letter can be
  # generated. Deliberately not validated for presence: sites are created without
  # them (the manager supplies them), and recalc_totals! saves legacy sites that
  # predate the requirement. "Is it filled in?" is a question of status, shown on
  # the manager's Compliance page, not of record validity.
  COMPLIANCE_FIELDS = {
    legal_name:              "Registered name of your organisation",
    signatory_name:          "Name of the person signing",
    signatory_title:         "Job title of the person signing",
    max_kg_per_delivery:     "Most kg you can accept per delivery",
    max_deliveries_per_week: "Most deliveries you can accept per week"
  }.freeze
  # not_submitted -> submitted (manager uploads) -> approved | rejected (Gooi reviews).
  # Only approved sites count as listed facilities, and only they can be paid.
  enum :facility_letter_status, %i[not_submitted submitted approved rejected], prefix: :letter

  LETTER_TYPES = %w[application/pdf image/jpeg image/png].freeze

  # Enum for collection day
  enum :collection_day, Date::DAYNAMES

  # Scopes
  scope :protein_capable, -> { where(accepts_protein: true) }
  # Sites that bill us for disposal. Free sites (Soil for Life) sit at 0.
  scope :charging,        -> { where("fee_per_kg > 0") }
  # Sites still owing us the paperwork (legacy sites, or onboarding skipped).
  scope :missing_facility_letter, -> { where.missing(:facility_confirmation_letter_attachment) }

  # Disposal fees owed to this site for a calendar month: completed drop-offs
  # only, weighed against the kilograms the driver recorded on the event.
  # Drops before fee_start_date are free; a NULL start date means no cutoff.
  def fees_for(year:, month:)
    period = Date.new(year, month, 1)..Date.new(year, month, 1).end_of_month
    events = drop_off_events.where(is_done: true, date: period)
    events = events.where(date: fee_start_date..) if fee_start_date
    kg = events.sum(:weight_kg).to_f.round(2)

    { kg: kg, fee: (kg * fee_per_kg.to_f).round(2) }
  end

  def fees_started?(on: Date.current)
    fee_start_date.nil? || fee_start_date <= on
  end

  def missing_compliance_fields
    COMPLIANCE_FIELDS.reject { |field, _| self[field].present? }.values
  end

  def compliance_details_complete?
    missing_compliance_fields.empty?
  end

  # Once the letter is approved the figures are what was signed, so the manager
  # can no longer change them (they ask Gooi). Prevents silent drift.
  def compliance_details_locked?
    letter_approved? && compliance_details_complete?
  end

  # Anything the manager still has to do: fill in details, or sign and upload the
  # letter. A letter awaiting Gooi's review is on us, not them. Drives the
  # "action needed" banner and nav dot.
  def action_needed?
    !compliance_details_complete? || letter_not_submitted? || letter_rejected?
  end

  def facility_paperwork_complete?
    compliance_details_complete? && letter_approved?
  end

  # What is still outstanding, for admin lists. nil when the site is fully listed.
  def paperwork_issue
    return "Letter awaiting review" if letter_submitted?
    return "Letter rejected" if letter_rejected?
    return "Details not filled in" if letter_not_submitted? && !compliance_details_complete?
    return "Letter not uploaded" if letter_not_submitted?

    "Details missing" unless compliance_details_complete?
  end

  # Does this delivery push the site past what its facility letter promised?
  # Returns human-readable reasons (empty when fine or when no limits are set).
  def capacity_overages_for(event)
    reasons = []
    if max_kg_per_delivery && event.weight_kg.to_f > max_kg_per_delivery.to_f
      reasons << "#{event.weight_kg.to_f.round(1)} kg delivered, over the #{max_kg_per_delivery.to_f.round(1)} kg per delivery limit"
    end
    if max_deliveries_per_week
      week = event.date.beginning_of_week..event.date.end_of_week
      count = drop_off_events.where(is_done: true, date: week).count
      reasons << "#{count} deliveries this week, over the #{max_deliveries_per_week} per week limit" if count > max_deliveries_per_week
    end
    reasons
  end

  # Gooi pays disposal fees only to sites listed as facilities.
  def payable?
    letter_approved?
  end

  # A manager's upload goes to Gooi for review. Status and file save together so a
  # bad file (wrong type, too big) leaves the site exactly as it was.
  def submit_facility_letter(upload)
    assign_attributes(facility_letter_status: :submitted, facility_letter_submitted_at: Time.current,
                      facility_rejection_reason: nil)
    facility_confirmation_letter.attach(upload)
    save
  end

  def approve_letter!
    update!(facility_letter_status: :approved, facility_approved_at: Time.current, facility_rejection_reason: nil)
  end

  def reject_letter!(reason)
    update!(facility_letter_status: :rejected, facility_rejection_reason: reason.presence)
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
    return [] unless Suburb.collection_days.key?(day.to_s.capitalize)
    Suburb.active.where(collection_day: day.to_s.capitalize).order(:name).pluck(:name)
  end

  # Instance method to get suburbs served by this drop-off site
  def served_suburbs
    self.class.suburbs_for_day(collection_day)
  end

  private

  def acceptable_facility_letter
    return unless facility_confirmation_letter.attached?

    blob = facility_confirmation_letter.blob
    errors.add(:facility_confirmation_letter, "must be a PDF, JPG or PNG") unless LETTER_TYPES.include?(blob.content_type)
    errors.add(:facility_confirmation_letter, "must be under 10 MB") if blob.byte_size > 10.megabytes
  end

  def generate_slug
    self.slug = name.parameterize
  end

end
