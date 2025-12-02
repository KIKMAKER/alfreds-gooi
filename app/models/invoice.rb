class Invoice < ApplicationRecord
  belongs_to :subscription, optional: true
  has_one :user, through: :subscription
  has_many :invoice_items, dependent: :destroy
  accepts_nested_attributes_for :invoice_items,
                                 allow_destroy: true,
                                 reject_if: proc { |attributes| attributes['quantity'].blank? || attributes['quantity'].to_f <= 0 }
  has_many :payments, dependent: :nullify
  has_many :invoice_discount_codes, dependent: :destroy
  has_many :discount_codes, through: :invoice_discount_codes

  # validates :issued_date, :due_date, :total_amount, presence: true
  after_commit :set_number, on: :create
  ## custom methods

  def set_number
    last_invoice = Invoice.where.not(id: self.id).order(created_at: :desc).first
    new_number = if last_invoice.nil? || last_invoice.number.nil?
                   1
                 else
                   last_invoice.number.to_i + 1
                 end
    self.update_column(:number, new_number)
  end

  def calculate_total
    # Calculate the total from the invoice items' amount * quantity
    subtotal = invoice_items.sum { |item| (item.amount || 0) * (item.quantity || 0) }

    # Subtract any discount codes applied
    discounts = invoice_discount_codes.sum(:discount_amount) || 0

    total = subtotal - discounts

    # Ensure total doesn't go negative
    total = 0 if total.negative?

    # Update the invoice's total_amount field
    if self.update!(total_amount: total)
      puts "Total amount updated successfully"
    else
      puts "Failed to update total amount: #{self.errors.full_messages.join(", ")}"
    end
  end

end
