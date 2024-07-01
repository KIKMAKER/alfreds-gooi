class Invoice < ApplicationRecord
  belongs_to :subscription, dependent: :destroy
  belongs_to :user, dependent: :destroy
  has_many :invoice_items, dependent: :destroy

  # validates :issued_date, :due_date, :total_amount, presence: true
  after_commit :set_number, on: :create
  ## custom methods

  def set_number
    last_invoice = Invoice.last
    puts last_invoice
    self.number = if last_invoice.nil?
                            1
                          elsif Invoice.last.number.to_i
                            Invoice.last.number.to_i + 1
                          else
                            Invoice.last.number
                          end
  end

  def calculate_total
    # self.total_amount = invoice_items.sum('amount * quantity')
    self.update(total_amount: invoice_items.sum('amount * quantity'))
    if self.save!
      puts "Total amount updated successfully"
    else
      puts "Failed to update total amount: #{self.errors.full_messages.join(", ")}"
    end
  end

end
