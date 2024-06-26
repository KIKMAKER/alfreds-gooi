class Invoice < ApplicationRecord
  belongs_to :subscription
  belongs_to :user

  validates :issue_date, :due_date, :total_amount, presence: true
end
