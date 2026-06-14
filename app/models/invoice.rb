class Invoice < ApplicationRecord
  belongs_to :subscription, optional: true
  belongs_to :order, optional: true
  has_one :user, through: :subscription
  has_many :invoice_items, dependent: :destroy
  accepts_nested_attributes_for :invoice_items,
                                 allow_destroy: true,
                                 reject_if: proc { |attributes| attributes['quantity'].blank? || attributes['quantity'].to_f <= 0 }
  has_many :payments, dependent: :nullify
  has_many :invoice_discount_codes, dependent: :destroy
  has_many :discount_codes, through: :invoice_discount_codes
  has_many :revenue_recognitions, dependent: :destroy

  validates :issued_date, :due_date, :total_amount, presence: true

  scope :paid,   -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }

  after_commit :set_number, on: :create
  after_update :create_revenue_recognitions, if: :saved_change_to_paid?

  def for_order?
    order_id.present?
  end

  ## custom methods

  def set_number
    num = self.class.connection.select_value("SELECT nextval('invoice_number_seq')").to_i
    update_column(:number, num)
  end

  def calculate_total
    # Calculate the total from the invoice items' amount * quantity
    subtotal = invoice_items.sum { |item| (item.amount || 0) * (item.quantity || 0) }

    # Subtract any discount codes applied
    discounts = invoice_discount_codes.sum(:discount_amount) || 0

    total = subtotal - discounts

    # Ensure total doesn't go negative
    total = 0 if total.negative?

    self.update!(total_amount: total)
  end

  private

  def create_revenue_recognitions
    CreateRevenueRecognitionsJob.perform_later(id) if paid?
  end
end
