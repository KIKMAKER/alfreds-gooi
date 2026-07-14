class Collection < ApplicationRecord
  belongs_to :subscription
  belongs_to :drivers_day, optional: true
  has_one :user, through: :subscription
  has_many :orders, dependent: :nullify

  # Scopes
  scope :recent,    -> { order(date: :desc) }
  scope :active,    -> { where(skip: false) }
  scope :for_date,  ->(date) { where(date: date) }
  scope :completed, -> { where(is_done: true) }

  before_save :stamp_collection_time
  before_save :sync_drivers_day_with_date, if: :needs_drivers_day_sync?

  # Custom methods
  # One-shot helper to mark skip + send email notification.
  # Use this for human-triggered skips (admin, customer "skip next week").
  def mark_skipped!(by: nil, reason: "unspecified", at: Time.zone.now)
    return false if skip? # avoid double-emails

    transaction do
      update!(skip: true, skip_reason: reason)
      CollectionMailer.skipped(
        collection_id: id,
        actor_id: by&.id,
        reason: reason,
        occurred_at: at
      ).deliver_now
    end
    true
  end

  # Silently mark as skipped with a reason — no email.
  # Use this in jobs creating collections for already-paused/holiday periods.
  def skip_silently!(reason:)
    return false if skip?
    update!(skip: true, skip_reason: reason)
    true
  end

  # ── Per-collection action links (soil bag, skip) ────────────────────────
  #
  # Customers act on a single collection from a WhatsApp link without logging
  # in. Each action has its own short-code column so links are independent: one
  # can be revoked without touching the other, and a skip link can never claim a
  # bag or vice versa.
  #
  # Ambiguous glyphs are excluded so a code can be read down a phone without
  # "was that an oh or a zero". 31 symbols over 8 places is ~8.5e11 codes, and
  # only collections we actually send a link for get one.
  ACTION_TOKEN_ALPHABET = (("a".."z").to_a - %w[i l o] + ("2".."9").to_a).freeze
  ACTION_TOKEN_LENGTH = 8
  ACTION_TOKEN_COLUMNS = %i[soil_bag_token skip_token].freeze

  def self.generate_action_token
    Array.new(ACTION_TOKEN_LENGTH) { ACTION_TOKEN_ALPHABET.sample(random: SecureRandom) }.join
  end

  # Look a collection up by one of its action tokens, refusing a blank token so
  # an empty URL segment can't match a null column. A link is only live while
  # its collection is still in the future — the collection date is the expiry,
  # so there's no TTL column and no link outlives its point.
  def self.find_by_action_token!(column, token)
    raise ArgumentError, "unknown action token column #{column}" unless ACTION_TOKEN_COLUMNS.include?(column)
    raise ActiveRecord::RecordNotFound if token.blank?

    collection = find_by!(column => token.to_s)
    raise ActiveRecord::RecordNotFound if collection.action_link_expired?

    collection
  end

  # Mint on demand and keep it — the same collection always yields the same link,
  # so re-sending a WhatsApp message doesn't strand the customer's first link.
  def ensure_action_token!(column)
    raise ArgumentError, "unknown action token column #{column}" unless ACTION_TOKEN_COLUMNS.include?(column)
    return self[column] if self[column].present?

    attempts = 0
    begin
      update_column(column, self.class.generate_action_token)
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 5
      raise
    end

    self[column]
  end

  def action_link_expired?
    date.nil? || date < Date.current
  end

  # Soil bag claim link.
  def ensure_soil_bag_token! = ensure_action_token!(:soil_bag_token)
  def revoke_soil_bag_token! = update_column(:soil_bag_token, nil)
  def self.find_by_soil_bag_token!(token) = find_by_action_token!(:soil_bag_token, token)

  # Skip-your-next-collection link.
  def ensure_skip_token! = ensure_action_token!(:skip_token)
  def revoke_skip_token! = update_column(:skip_token, nil)
  def self.find_by_skip_token!(token) = find_by_action_token!(:skip_token, token)

  def soil_bag_claimed?
    soil_bag.to_i.positive?
  end

  def done?
    is_done
  end

  def skip?
    skip
  end

  def kiki_note_nil_zero?
    kiki_note.nil? || kiki_note == ""
  end

  # Method to check if the collection is for today's date
  def today?
    self.date == Date.current
  end

  def volume_litres
    sub = subscription
    return 0 unless sub

    if sub.Standard? || sub.once_off?
      bags.to_i * 5
    else
      # XL and Commercial: use actual tracked bucket sizes where available,
      # fall back to total buckets × 25L if sizes haven't been recorded yet.
      sized = (buckets_25l.to_i * 25) + (buckets_45l.to_i * 45)
      sized.positive? ? sized : (buckets.to_i * 25)
    end
  end

  # Save data outside of heroku
  def self.to_csv
    attributes = %w[id created_at updated_at subscription_id date kiki_note alfred_message bags buckets is_done skip drivers_day_id new_customer buckets]

    CSV.generate(headers: true) do |csv|
      csv << attributes

      all.find_each do |collection|
        csv << attributes.map { |attr| collection.send(attr) }
      end
    end
  end

  # Point the collection at the driver's DriversDay for its date, appending it
  # to the end of that day's route. Runs automatically (via callback) when the
  # date of an existing collection changes; call it explicitly when building a
  # new collection that should join a route.
  def sync_drivers_day_with_date
    return if date.blank?

    driver = User.find_by(role: :driver)
    new_day = driver && DriversDay.find_or_create_by!(date: date, user: driver)
    return if new_day&.id == drivers_day_id

    self.drivers_day = new_day
    return if will_save_change_to_position?

    self.position = new_day && (new_day.collections.where.not(id: id).maximum(:position).to_i + 1)
  end

  private

  def stamp_collection_time
    self.time = Time.current if will_save_change_to_is_done? && is_done?
  end

  # Only sync on date edits to existing records; creation paths (jobs, admin)
  # assign the drivers_day explicitly, and an explicit drivers_day change wins.
  def needs_drivers_day_sync?
    persisted? && will_save_change_to_date? && !will_save_change_to_drivers_day_id?
  end
end
