class DriversDay < ApplicationRecord
  belongs_to :user
  has_many :collections
end
