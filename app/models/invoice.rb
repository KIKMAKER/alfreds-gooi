class Invoice < ApplicationRecord
  belongs_to :subscription, dependent: :destroy
  belongs_to :user, dependent: :destroy

  validates :issued_date, :due_date, :total_amount, presence: true
  after_commit :set_number, on: :create
  ## custom methods

  def set_number
    last_invoice = Invoice.last
    self.number = if last_invoice.nil?
                            1
                          elsif Invoice.last.number.to_i
                            Invoice.last.number.to_i + 1
                          else
                            Invoice.last.number
                          end
  end
end
