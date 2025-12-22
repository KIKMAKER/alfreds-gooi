class Quotation < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :subscription, optional: true
  has_many :quotation_items, dependent: :destroy
  has_many :products, through: :quotation_items

  # Nested attributes (same pattern as Invoice)
  accepts_nested_attributes_for :quotation_items,
                                allow_destroy: true,
                                reject_if: proc { |attributes|
                                  attributes['quantity'].blank? || attributes['quantity'].to_f <= 0
                                }

  # Enums
  enum :status, %i[draft sent accepted rejected expired]

  # Validations
  validates :created_date, :expires_at, presence: true
  validate :has_customer_or_prospect_details

  # Callbacks
  after_commit :set_number, on: :create

  # Scopes
  scope :active, -> { where('expires_at >= ?', Date.today).where.not(status: [:accepted, :rejected]) }
  scope :expired_status, -> { where('expires_at < ?', Date.today).or(where(status: :expired)) }
  scope :for_prospects, -> { where(user_id: nil) }
  scope :for_customers, -> { where.not(user_id: nil) }

  # Methods
  def set_number
    last_quotation = Quotation.where.not(id: self.id).order(created_at: :desc).first
    new_number = if last_quotation.nil? || last_quotation.number.nil?
                   1
                 else
                   last_quotation.number.to_i + 1
                 end
    self.update_column(:number, new_number)
  end

  def calculate_total
    subtotal = quotation_items.sum { |item| (item.amount || 0) * (item.quantity || 0) }
    total = subtotal
    total = 0 if total.negative?

    if self.update!(total_amount: total)
      Rails.logger.info "Total amount updated successfully for quotation #{self.id}"
    else
      Rails.logger.error "Failed to update total amount: #{self.errors.full_messages.join(", ")}"
    end
  end

  def expired?
    expires_at < Date.today || status == 'expired'
  end

  def customer_name
    if user.present?
      "#{user.first_name} #{user.last_name}"
    else
      prospect_name
    end
  end

  def customer_email
    user&.email || prospect_email
  end

  def is_prospect?
    user_id.nil?
  end

  private

  def has_customer_or_prospect_details
    if user_id.nil? && prospect_name.blank?
      errors.add(:base, "Must have either a customer or prospect name")
    end
  end
end
