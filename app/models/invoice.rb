class Invoice < ApplicationRecord
  belongs_to :subscription, dependent: :destroy
  belongs_to :user, dependent: :destroy

  validates :issued_date, :due_date, :total_amount, presence: true
end
