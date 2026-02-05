class WhatsappMessage < ApplicationRecord
  belongs_to :user
  belongs_to :subscription, optional: true

  validates :message_type, presence: true
  validates :message_body, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where(status: ['failed', 'undelivered']) }
  scope :delivered, -> { where(status: 'delivered') }
  scope :for_date, ->(date) { where(collection_date: date) }

  def delivered?
    status == 'delivered'
  end

  def failed?
    ['failed', 'undelivered'].include?(status)
  end
end
