class Invoice < ApplicationRecord
  belongs_to :subscription, dependent: :destroy
  has_one :user, through: :subscription
  has_many :invoice_items, dependent: :destroy

  # validates :issued_date, :due_date, :total_amount, presence: true
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

  def calculate_total
  # Calculate the total from the invoice items' amount * quantity
  total = invoice_items.sum { |item| item.amount * item.quantity }

  # Update the invoice's total_amount field
  self.update(total_amount: total)

  if self.save
    puts "Total amount updated successfully"
  else
    puts "Failed to update total amount: #{self.errors.full_messages.join(", ")}"
  end
  end

end
