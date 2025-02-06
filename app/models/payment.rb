class Payment < ApplicationRecord
  belongs_to :user
  belongs_to :invoice, optional: true
end
