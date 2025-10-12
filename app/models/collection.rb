class Collection < ApplicationRecord
  belongs_to :subscription, optional: true
  belongs_to :drivers_day, optional: true
  has_one :user, through: :subscription
  has_many :orders, dependent: :nullify
  acts_as_list scope: :drivers_day

  # Scopes
  scope :recent, -> { order(date: :desc) }

  # Custom methods
  # One-shot helper to mark skip + email (use this everywhere instead of bare update)
  def mark_skipped!(by: nil, reason: "unspecified", at: Time.zone.now)
    return false if skip? # avoid double-emails

    transaction do
      update!(skip: true)
      CollectionMailer.skipped(
        collection_id: id,
        actor_id: by&.id,
        reason: reason,
        occurred_at: at
      ).deliver_now
    end
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

  def notify_skip_marked(user)
    CollectionMailer.skipped(
      collection_id: id,
      actor_id: user.id,  # optional: if you use Current attributes
      reason: "model_update",
      occurred_at: Time.zone.now
    ).deliver_now
  end

end
