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

  private

  def stamp_collection_time
    self.time = Time.current if will_save_change_to_is_done? && is_done?
  end

end
