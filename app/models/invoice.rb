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
  # Accrual-basis revenue recognition: rows are (re)built whenever the amount
  # or issue date changes, independent of payment status. calculate_total
  # fires this after items are added, so new invoices are covered too.
  after_commit :sync_revenue_recognitions, on: %i[create update],
               if: -> { saved_change_to_total_amount? || saved_change_to_issued_date? }

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

  def sync_revenue_recognitions
    # perform_now: there is no worker dyno in production, so perform_later
    # would enqueue into the queue DB and never run. Rescued so a recognition
    # problem can never break invoice creation or editing.
    SyncRevenueRecognitionsJob.perform_now(id)
  rescue StandardError => e
    Rails.logger.error("[Invoice#sync_revenue_recognitions] #{e.class} — #{e.message}")
  end
end
