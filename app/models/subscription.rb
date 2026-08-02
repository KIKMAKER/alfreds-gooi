class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :block, optional: true
  belongs_to :suburb
  has_many :collections, dependent: :nullify
  has_many :invoices, dependent: :nullify
  has_many :invoice_items, through: :invoices
  has_many :referrals, dependent: :nullify
  has_one :business_profile, dependent: :nullify
  # Recognition rows are invoice-anchored financial history; they must survive
  # subscription deletion or recognized revenue silently decays.
  has_many :revenue_recognitions, dependent: :nullify
  has_many :contacts, dependent: :destroy
  accepts_nested_attributes_for :contacts, allow_destroy: true, reject_if: :all_blank

  # Records which accepted quotation created this subscription (nil for non-quote subscriptions).
  belongs_to :quotation, optional: true

  # Cached product references set by InvoiceBuilder / MonthlyInvoiceService to avoid
  # repeated title lookups on subsequent invoice runs.
  belongs_to :subscription_product,        class_name: "Product", optional: true
  belongs_to :monthly_collection_product,  class_name: "Product", optional: true
  belongs_to :volume_processing_product,   class_name: "Product", optional: true

  # Satellite subscriptions exist only to generate collections on a second collection day.
  # All billing flows through the primary. Satellites are never invoiced independently.
  belongs_to :primary_subscription, class_name: "Subscription", optional: true
  has_many :satellite_subscriptions, class_name: "Subscription", foreign_key: :primary_subscription_id, dependent: :nullify

  def satellite?
    primary_subscription_id.present?
  end

  before_create do
    self.set_customer_id unless self.customer_id
    # self.set_suburb
  end
  before_create :inherit_collection_order
  after_create :create_owner_contact
  after_save :sync_collection_positions
  before_validation :set_collection_day, if: -> { (will_save_change_to_street_address? || will_save_change_to_suburb_id?) && collection_day.nil? }
  before_validation :normalize_referral_code
  # Fallback used when the suburbs table is missing or empty (fresh dev/CI boot).
  # Kept in sync with the backfill in db/migrate/20260720103529_create_suburbs.rb.
  FALLBACK_SUBURBS = ["Bakoven", "Bantry Bay", "Camps Bay", "Cape Town", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "District Six", "Ndabeni", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Woodstock", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Observatory", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "Southfield", "Steenberg", "Tokai", "Witteboomen", "Wynberg", "Clovelly", "Fish Hoek", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort.freeze

  # DB-backed replacement for the old frozen SUBURBS constant. Falls back to
  # FALLBACK_SUBURBS when the suburbs table doesn't exist yet or hasn't been
  # backfilled (fresh dev/CI boot).
  def self.SUBURBS
    return FALLBACK_SUBURBS unless Suburb.table_exists?
    names = Suburb.active.pluck(:name)
    names.empty? ? FALLBACK_SUBURBS : names.sort
  end

  validates :street_address, presence: true
  validates :plan, presence: true
  validates :duration, presence: true, unless: :once_off?
  validates :bucket_size, inclusion: { in: [25, 45] }, if: :Commercial?
  validates :buckets_per_collection, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 20 }, if: :Commercial?
  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?

  # Mailchimp sync callbacks
  after_commit :sync_to_mailchimp, if: :should_sync_to_mailchimp?



  # accepts_nested_attributes_for :contacts
  # accepts_nested_attributes_for :user

  # scopes
  scope :pending, -> { where(status: :pending) }
  scope :active, -> { where(status: :active) }
  scope :paused, -> { where(status: :pause) }
  scope :completed, -> { where(status: :completed) }
  scope :order_by_user_name, -> { joins(:user).order('users.first_name ASC') }
  scope :protein, -> { where(waste_stream: :protein) }
  scope :general, -> { where(waste_stream: :general) }

  ## VALIDATIONS

  ## ENUMS
  enum :status, %i[pending active pause completed legacy]
  enum :plan, %i[once_off Standard XL Commercial]
  enum :collection_day, Date::DAYNAMES
  # Suffixed so the predicates read `protein_waste_stream?` rather than claiming
  # the generic `general?`/`protein?` names on the model.
  enum :waste_stream, %i[general protein], suffix: true

  # Constants
  GRACE_BACK_DAYS = 7  # Grace period for subscription continuity when resubscribing

  def calculate_next_collection_day
    target_day = Date::DAYNAMES.index(collection_day.capitalize)
    current_day = Time.zone.today.wday # Use Time.zone.today for time zone awareness
    days_until_next_collection = (target_day - current_day) % 7
    days_until_next_collection = 7 if days_until_next_collection.zero?
    Rails.logger.debug "next collection day: #{Time.zone.today + days_until_next_collection}"
    Time.zone.today + days_until_next_collection # Use Time.zone.today here as well
  end

  def display_name
    title.presence || user.first_name
  end

  def total_collections
    collections.where(skip: false).count
  end

  def remaining_collections
    return 1 - total_collections if once_off?
    return nil if duration.nil?
    total = duration * 4.2
    remaining = total.ceil - self.total_collections
    return remaining
  end

  def skipped_collections
    collections.where(skip: true).count
  end

  def total_bags
    collections.sum(:bags)
  end

  def total_buckets
    collections.sum(:buckets)
  end

  def total_bags_last_n_months(n)
    collections.where("created_at >= ?", n.months.ago).sum(:bags)
  end

  def total_buckets_last_n_months(n)
    collections.where("created_at >= ?", n.months.ago).sum(:buckets)
  end

  def allowed_litres_per_collection
    if Commercial?
      (buckets_per_collection || 1) * (bucket_size || 45)
    elsif XL?
      25
    else
      5
    end
  end

  # Expected litres collected per week based on this subscription's own config.
  # Used by Block#expected_weekly_volume_l to sum across linked subscriptions.
  def expected_weekly_volume_l
    allowed_litres_per_collection * (collections_per_week || 1)
  end

  # Mirrors the per-row volume_litres logic: use sized bucket columns when
  # populated, fall back to raw buckets × 25L. This handles cases where drivers
  # record XL-style buckets on Commercial subs (or vice versa).
  BUCKET_VOLUME_SQL = <<~SQL.squish
    CASE
      WHEN COALESCE(buckets_25l, 0) > 0 OR COALESCE(buckets_45l, 0) > 0
        THEN COALESCE(buckets_25l, 0) * 25 + COALESCE(buckets_45l, 0) * 45
      ELSE COALESCE(buckets, 0) * 25
    END
  SQL

  def total_litres
    if Standard? || once_off?
      collections.sum("bags * 5")
    else
      collections.sum(BUCKET_VOLUME_SQL)
    end
  end

  # Human-readable summary of volume collected (skipped collections excluded).
  # Used in subscription completion/ending-soon emails so templates stay plan-agnostic.
  def collected_volume_display
    non_skipped = collections.where(skip: false)
    if Commercial?
      litres = non_skipped.sum(BUCKET_VOLUME_SQL)
      "#{litres}L"
    elsif XL?
      "#{non_skipped.sum(:buckets)} buckets"
    else
      "#{non_skipped.sum(:bags)} bags"
    end
  end

  def total_litres_last_n_months(n)
    scope = collections.where("created_at >= ?", n.months.ago)
    if Standard? || once_off?
      scope.sum("bags * 5")
    else
      scope.sum(BUCKET_VOLUME_SQL)
    end
  end

  # Real litres actually collected between two dates (excludes skipped rows).
  # Used by RandsPerLitre#realised_r_per_litre — deliberately date-bounded
  # rather than "n months ago" so it can be pinned to the same complete-months
  # window CostModel uses elsewhere.
  def total_litres_between(start_date, end_date)
    scope = collections.where(skip: false, date: start_date..end_date)
    if Standard? || once_off?
      scope.sum("bags * 5")
    else
      scope.sum(BUCKET_VOLUME_SQL)
    end
  end

  def avg_litres_per_collection
    return 0 if total_collections.zero?
    (total_litres.to_f / total_collections).round(1)
  end

  def amount_invoiced
    return 0 unless monthly_invoicing?
    invoices.sum(:total_amount)
  end

  def amount_remaining
    return 0 unless monthly_invoicing?
    return 0 unless contract_total
    contract_total - amount_invoiced
  end

  def invoicing_progress_percentage
    return 0 unless monthly_invoicing?
    return 0 unless contract_total && contract_total.positive?
    (amount_invoiced / contract_total * 100).round
  end

  def self.active_subs_for(day)
    # Despite the name, this used to match on collection_day alone — any status.
    # That was harmless while every subscription with a collection_day was already
    # active-or-about-to-be, but the suburb launch mechanic introduced long-lived
    # `pending` subscriptions with collection_day already set (paid, deferred until
    # the suburb goes live). Without the status filter, a deferred subscription
    # would show up on the driver's daily list (today_notes) on its collection day
    # weeks before the suburb actually launches.
    active.where(collection_day: day).includes(:collections).order(:collection_order)
  end

  def self.count_skip_subs_for(day)
    active_subs_for(day).where(collections: { skip: true }).distinct.count
  end

  def self.humanized_plans
    {
      once_off: 'Once-off',
      Standard: 'Standard',
      XL: 'Extra Large',
      Commercial: 'Commercial'
    }
  end

  def human_plan
    self.class.humanized_plans[plan.to_sym] || plan
  end

  def is_paused?(on_date: Date.today)
    is_paused || holiday_covers?(on_date)
  end

  def holiday_covers?(date)
    holiday_start.present? && date >= holiday_start && date <= holiday_end
  end

  def complete?
    status == "completed"
  end

  def end_date!
    collections = self.collections.where(skip: false).count
    self.update!(end_date: (start_date + collections.weeks).to_date) if start_date
  end

  def set_collection_day
    self.collection_day = suburb&.collection_day
    Rails.logger.warn "suburb allocation issue for #{user.first_name} in #{suburb&.name}" if collection_day.nil?
  end

  def set_customer_id
    return if self.customer_id.present?
    self.customer_id = user.customer_id
  end

  # Suggest a start date for THIS subscription.
  #
  # Rules:
  # - If there's no previous completed sub → start on payment date.
  # - If they paid before the last sub ended → day after last_end.
  # - If they paid within GRACE_BACK_DAYS after last_end → day after last_end.
  # - FAILSAFE: if any non-skipped collections happened in the gap → day after last_end.
  # - Otherwise (long gap, no pickups) → payment date.
  # - Then (optionally) align to this sub's collection weekday for clean routing.
  #
  # Returns a Date.
  def suggested_start_date(payment_date: Date.current, align_to_collection_day: true)
    paid_on  = payment_date.to_date
    # FIXED: Find most recent subscription regardless of status (not just completed)
    last_sub = user.subscriptions.where.not(id: id).order(created_at: :desc).first

    base =
      if last_sub&.start_date.present?
        # Calculate expected end based on subscription details
        last_end = if last_sub.end_date.present?
          # If end_date exists, use it
          last_sub.end_date.to_date
        elsif last_sub.duration.present?
          # Calculate expected end based on required collections
          required_collections = (4 * last_sub.duration).ceil
          # Expected end = start + total_required_collections.weeks
          (last_sub.start_date + required_collections.weeks).to_date
        else
          # No end_date and no duration (e.g. a once_off subscription) — nothing
          # to project forward from, so treat start_date as the last known point.
          last_sub.start_date.to_date
        end

        # FAILSAFE: if you actually collected in the gap, force continuity
        had_pickups_in_gap = user.collections
                                .where(skip: false)
                                .where(date: (last_end + 1.day)..paid_on)
                                .exists?

        if had_pickups_in_gap || paid_on <= last_end || paid_on <= (last_end + GRACE_BACK_DAYS)
          last_end + 1.day
        else
          paid_on
        end
      else
        paid_on
      end

    return base unless align_to_collection_day

    ruby_wday = normalize_to_ruby_wday(collection_day)
    ruby_wday ? align_to_wday(base, ruby_wday) : base
  end

  # Reattach any future collections to this subscription once it has a start_date.
  # FIXED: Only adopts from completed subscriptions or orphaned collections
  # (won't steal from active/paused subscriptions)
  # Safe to run multiple times.
  def adopt_future_collections!
    raise ArgumentError, "start_date required" unless start_date

    self.class.transaction do
      # Only adopt collections that:
      # 1. Are >= our start_date AND
      # 2. Either have no subscription_id (orphaned), OR
      # 3. Belong to a COMPLETED subscription

      # Find completed subscription IDs
      completed_sub_ids = user.subscriptions.completed.pluck(:id)

      user.collections
          .where("date >= ?", start_date.to_date)
          .where.not(subscription_id: id)
          .where(
            "subscription_id IS NULL OR subscription_id IN (?)",
            completed_sub_ids
          )
          .update_all(subscription_id: id)
    end
  end

  # Move this sub's future collections to the next sub in line.
  # Next sub = same user, earliest start_date strictly AFTER *this sub's end*.
  # If this sub has no end_date, we use (start_date + duration.months), else fallback to start_date.
  #
  # Returns a hash compatible with your controller messaging.
  def reassign_user_collections!(dry_run: false)
    raise "Subscription must have a user" unless user
    raise "Subscription must have a start_date" unless start_date
    cols = collections.where(skip: false).count
    # Determine this sub's "end" for the purpose of finding the *next* sub
    this_end =
      if end_date.present?
        end_date.to_date
      elsif collections.any?
        (start_date + cols.weeks).to_date
      else
        start_date.to_date
      end

    # Find the next sub strictly after "this_end"
    next_sub = user.subscriptions
                   .where("start_date >= ?", this_end)
                   .order(:start_date)
                   .first

    return {
      dry_run: dry_run,
      updated_total: 0,
      next_sub_id: nil,
      boundary: nil,
      unmatched: [],      # kept for API compat
      to_move_ids: []     # present in dry runs
    } unless next_sub&.start_date

    boundary = next_sub.start_date.to_date

    # Only move collections that currently belong to THIS sub
    scope = collections.where("date >= ?", boundary)
    ids_to_move = scope.pluck(:id)

    if dry_run
      {
        dry_run: true,
        updated_total: 0,
        next_sub_id: next_sub.id,
        boundary: boundary,
        unmatched: [],
        to_move_ids: ids_to_move
      }
    else
      moved = Collection.where(id: ids_to_move).update_all(subscription_id: next_sub.id)
      {
        dry_run: false,
        updated_total: moved,
        next_sub_id: next_sub.id,
        boundary: boundary,
        unmatched: []
      }
    end
  end


  # Map collection_day to Ruby's Date#wday (0=Sun..6=Sat).
  # Adjust this if your enum differs.
  def normalize_to_ruby_wday(val)
    case val
    when Integer
      # If your enum already uses Ruby's 0..6, return as-is.
      # If it's 1..7 (Mon..Sun), change to: (val % 7)
      val
    when String
      # Accept "Monday", "tuesday", etc.
      idx = Date::DAYNAMES.index(val.to_s.capitalize)
      idx.nil? ? nil : idx
    else
      nil
    end
  end

  # Align to the same or next occurrence of ruby_wday (0..6).
  # If you want *always next week* when it's the same day, replace last line with:
  #   delta = 7 if delta.zero?
  def align_to_wday(date, ruby_wday)
    delta = (ruby_wday - date.wday) % 7
    delta = 7 if delta.zero?
    date + delta
  end

  def normal_activation_start_date
    once_off? && start_date.present? ? start_date : suggested_start_date
  end

  # launch_date - 1.week, aligned to the suburb's collection weekday, clamped forward
  # so it's never earlier than what a normal signup would compute — covers paying on
  # or after the actual launch_date while the suburb hasn't been manually flipped live
  # yet (Suburb#waitlist? deliberately doesn't auto-close on the date itself).
  def deferred_launch_start_date
    earliest = suburb.launch_date - 1.week
    ruby_wday = normalize_to_ruby_wday(collection_day)
    aligned_earliest = ruby_wday ? align_to_wday(earliest, ruby_wday) : earliest
    [aligned_earliest, normal_activation_start_date].max
  end

  def delete_invoices
    invoices.each { |inv| inv.invoice_items.delete_all }
    invoices.delete_all
  end

  def short_address
    return street_address if street_address.blank?
    street_address.split(',').first.strip
  end

  # A Mapbox-selected address is a full "<street>, <city>, <province> <postcode>,
  # South Africa" string. Anything shorter was hand-typed and may be missing the
  # suburb/postcode a driver needs to find the house.
  def complete_mapbox_address?
    street_address.to_s.match?(/South Africa\s*\z/i)
  end

  # True when the suburb field's own name doesn't even appear in the address text —
  # a stronger signal than "just incomplete": the suburb itself may be wrong.
  def suburb_missing_from_address?
    return false if suburb.blank?
    !street_address.to_s.downcase.include?(suburb.name.downcase)
  end

  # Contact helper methods
  def primary_contact
    contacts.primary.first
  end

  def all_contacts_names
    contacts.pluck(:first_name, :last_name).map { |f, l| [f, l].compact.join(' ') }.join(', ')
  end

  def whatsapp_recipients
    contacts.can_receive_whatsapp
  end

  # Copy contacts from another subscription
  def copy_contacts_from(other_subscription)
    return if other_subscription.nil?

    other_subscription.contacts.each do |other_contact|
      # Don't duplicate if contact already exists with same phone
      next if contacts.exists?(phone_number: other_contact.phone_number)

      contacts.create(
        first_name: other_contact.first_name,
        last_name: other_contact.last_name,
        phone_number: other_contact.phone_number,
        relationship: other_contact.relationship,
        whatsapp_opt_out: other_contact.whatsapp_opt_out,
        is_primary: false # New subscription, new owner
      )
    end
  end

  def create_referral_from_code
    return if referral_code.blank?
    referrer = User.find_by(referral_code: referral_code)
    return unless referrer
    return if referrer == user

    existing = user.referrals_as_referee.first

    if existing
      return if existing.used?           # credit already applied, too late to change
      return if existing.referrer == referrer  # nothing to change
      existing.update!(referrer: referrer, subscription: self)
    else
      status = active? ? :completed : :pending
      Referral.create!(subscription: self, referee: user, referrer: referrer, status: status)
    end

    user.update_column(:referred_by_code, referral_code)
  end

  # Returns true if the subscription actually went active, false if it was deferred
  # (waitlist suburb) — callers use this to decide whether to run
  # CreateFirstCollectionJob now. A deferred subscription's first collection must
  # wait for Suburb#go_live!, not fire on payment, or a driver's route would gain a
  # stop for a suburb that isn't being serviced yet.
  def activate_subscription
    # A waitlist suburb (locked-in-rate pre-launch signup) stays pending until the
    # suburb actually goes live — Suburb#go_live! finds paid pending subs like this
    # one and calls finalize_deferred_activation! at that point. See
    # deferred_launch_start_date for why start_date still gets set now.
    deferred = suburb&.waitlist?
    resolved_start = deferred ? deferred_launch_start_date : normal_activation_start_date

    activation_attrs = { start_date: resolved_start, is_paused: false }
    activation_attrs[:status] = :active unless deferred
    update!(activation_attrs)

    effective_referral_code = referral_code.presence || user.referred_by_code
    if effective_referral_code.present?
      referrer = User.find_by(referral_code: effective_referral_code)
      if referrer
        referral = Referral.find_by(referee_id: user_id, referrer_id: referrer.id)
        if referral
          referral.completed!
          SubscriptionMailer.with(referrer: referrer, referee: user).referral_completed.deliver_now
        end
      end
    end

    # Send payment received confirmation email
    SubscriptionMailer.with(subscription: self, is_new: is_new_customer).payment_received.deliver_now
    SubscriptionMailer.with(subscription: self).payment_received_alert.deliver_now

    # Activate any satellite subscriptions so they also start generating collections
    satellite_subscriptions.where(status: :pending).each do |sat|
      sat_attrs = { start_date: resolved_start, is_paused: false }
      sat_attrs[:status] = :active unless deferred
      sat.update!(sat_attrs)
    end

    !deferred
  end

  # Called by Suburb#go_live! for a subscription whose payment already ran
  # activate_subscription while its suburb was still on the pre-launch waitlist.
  # start_date was already computed and clamped back then — this only flips
  # status, it never recomputes dates against "today" (go-live day may be long
  # after the original payment date).
  #
  # Re-syncs collection_day from the suburb here too: set_collection_day only
  # fires once, when suburb_id is first assigned, so a subscription created
  # before the suburb's collection_day was finalized (a real gap during
  # pre-launch admin setup) would otherwise stay stuck with a blank
  # collection_day forever — go-live is the one point we can guarantee the
  # suburb's collection_day is actually correct (Suburb requires it to be
  # active), so it's safe to trust here.
  def finalize_deferred_activation!
    update!(status: :active, collection_day: suburb.collection_day)
  end


  private

  def create_owner_contact
    return if contacts.exists?(is_primary: true)
    return if user.phone_number.blank?

    contacts.create(
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: user.phone_number,
      is_primary: true,
      whatsapp_opt_out: false
    )
  end

  def inherit_collection_order
    return if collection_order.present?
    previous = Subscription.where(user_id: user_id).where.not(collection_order: nil).order(created_at: :desc).first
    self.collection_order = previous.collection_order if previous
  end

  def sync_collection_positions
    return unless saved_change_to_collection_order?
    return if collection_order.blank?
    collections.where("date > ?", Date.today).update_all(position: collection_order)
  end

  def normalize_referral_code
    self.referral_code = referral_code.strip.upcase if referral_code.present?
  end

  # def set_customer_id
  #   return if self.customer_id.present?
  #   customers = User.where(role: 'customer').where.not(customer_id: nil)
  #   last_id = (customers.sort_by { |customer| customer.customer_id[4..-1].to_i }.last&.customer_id || "")[4..-1].to_i
  #   new_customer_id = "GFWC" + (last_id + 1).to_s
  #   self.update!(customer_id: new_customer_id)
  #   self.user.update!(customer_id: new_customer_id) if self.user.customer_id.nil?
  # end

  # Mailchimp sync methods
  def should_sync_to_mailchimp?
    return false unless Rails.env.production?
    return false unless user.present?
    return false unless ENV['MAILCHIMP_LIST_ID'].present?

    # Sync when status changes or when record is created
    saved_change_to_status? || saved_change_to_plan? || saved_change_to_collection_day? || previously_new_record?
  end

  def sync_to_mailchimp
    MailchimpSyncJob.perform_later(user.id)
  end

end
