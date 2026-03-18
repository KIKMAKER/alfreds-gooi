class Payment < ApplicationRecord
  belongs_to :user
  belongs_to :invoice, optional: true

  enum :payment_type, { eft: 'eft', snapscan: 'snapscan', cash: 'cash', other: 'other' }
end
