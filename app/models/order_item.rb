class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true

  before_validation :set_price_from_product, if: -> { price.nil? }

  def subtotal
    quantity * price
  end

  private

  def set_price_from_product
    self.price = product.price if product
  end
end
