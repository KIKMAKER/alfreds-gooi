class Payment < ApplicationRecord
  belongs_to :user
  belongs_to :invoice, optional: true

  enum :payment_type, { eft: 'eft', snapscan: 'snapscan', cash: 'cash', other: 'other' }

  validates :user, presence: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
end
