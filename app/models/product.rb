class Product < ApplicationRecord
  validates :description, :title, :price, presence: true
  has_many :invoice_items, dependent: :destroy
end
