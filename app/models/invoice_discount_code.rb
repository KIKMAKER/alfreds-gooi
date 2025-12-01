class InvoiceDiscountCode < ApplicationRecord
  belongs_to :invoice
  belongs_to :discount_code

  validates :discount_amount, presence: true
end
