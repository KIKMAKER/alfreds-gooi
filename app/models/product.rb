class Product < ApplicationRecord
  validates :description, :title, :price, presence: true
  has_many :invoice_items, dependent: :nullify
  has_many :quotation_items, dependent: :nullify
  has_many_attached :images

  scope :shop_items, -> { where(is_active: true) }
  scope :in_stock, -> { where("stock > ?", 0) }

  def in_stock?
    stock.to_i > 0
  end

  def out_of_stock?
    stock.to_i <= 0
  end

  def primary_image
    images.first
  end
end
