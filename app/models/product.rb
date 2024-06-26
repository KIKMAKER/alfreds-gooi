class Product < ApplicationRecord
  validates :description, :title, :price, presence: true
end
