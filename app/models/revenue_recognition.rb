class RevenueRecognition < ApplicationRecord
  # Associations
  belongs_to :invoice
  belongs_to :subscription

  # Validations
  validates :period_start, :period_end, :period_month, :period_year, :recognized_amount, presence: true
  validates :period_month, inclusion: { in: 1..12 }
  validates :recognized_amount, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_month, ->(year, month) { where(period_year: year, period_month: month) }
  scope :for_year, ->(year) { where(period_year: year) }
  scope :for_subscription, ->(subscription_id) { where(subscription_id: subscription_id) }

  # Class Methods
  def self.total_for_month(year, month)
    for_month(year, month).sum(:recognized_amount)
  end

  # Instance Methods
  def period_label
    Date.new(period_year, period_month, 1).strftime("%B %Y")
  end
end
