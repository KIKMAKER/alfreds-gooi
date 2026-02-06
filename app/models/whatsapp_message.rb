class WhatsappMessage < ApplicationRecord
  belongs_to :user, optional: true  # Keep for backward compatibility
  belongs_to :subscription, optional: true
  belongs_to :contact, optional: true  # NEW

  validates :message_type, presence: true
  validates :message_body, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where(status: ['failed', 'undelivered']) }
  scope :delivered, -> { where(status: 'delivered') }
  scope :for_date, ->(date) { where(collection_date: date) }
  scope :for_contact, ->(contact) { where(contact_id: contact.id) }

  def delivered?
    status == 'delivered'
  end

  def failed?
    ['failed', 'undelivered'].include?(status)
  end
end
