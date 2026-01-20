class QuotationItem < ApplicationRecord
  belongs_to :quotation
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
