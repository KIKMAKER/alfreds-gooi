class BusinessProfile < ApplicationRecord
  belongs_to :subscription
  belongs_to :suburb, optional: true
end
