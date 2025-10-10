class Order < ApplicationRecord
  belongs_to :user
  belongs_to :collection, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  enum :status, %i[pending paid delivered cancelled]

  before_save :calculate_total

  scope :for_collection, ->(collection) { where(collection: collection) }
  scope :pending_delivery, -> { where(status: [:pending, :paid]) }

  def calculate_total
    self.total_amount = order_items.sum { |item| item.quantity * item.price }
  end

  def mark_delivered!
    update!(status: :delivered, delivered_at: Time.current)
    decrease_stock!
  end

  private

  def decrease_stock!
    order_items.each do |item|
      product = item.product
      product.update!(stock: product.stock - item.quantity) if product.stock >= item.quantity
    end
  end
end
