class Quotation < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :subscription, optional: true
  belongs_to :block, optional: true
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
  attribute :quote_type, :string, default: "subscription"
  enum :quote_type, { subscription: "subscription", event: "event" }

  # Validations
  validates :created_date, :expires_at, presence: true
  validates :collections_per_week, numericality: { only_integer: true, greater_than: 0 }
  validates :buckets_per_collection, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :has_customer_or_prospect_details

  # Callbacks
  after_commit :set_number, on: :create

  # Scopes
  scope :active, -> { where('expires_at >= ?', Date.today).where.not(status: [:accepted, :rejected]) }
  scope :expired_status, -> { where('expires_at < ?', Date.today).or(where(status: :expired)) }
  scope :for_prospects, -> { where(user_id: nil) }
  scope :for_customers, -> { where.not(user_id: nil) }
  scope :event_quotes, -> { where(quote_type: "event") }
  scope :subscription_quotes, -> { where(quote_type: "subscription") }

  # Methods
  def set_number
    num = self.class.connection.select_value("SELECT nextval('quotation_number_seq')").to_i
    update_column(:number, num)
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

  def event?
    quote_type == "event"
  end

  def weeks_in_contract
    duration_months * 4
  end

  def weekly_rate
    return 0 if weeks_in_contract.zero? || total_amount.blank?
    (total_amount / weeks_in_contract).round(2)
  end

  def monthly_rate
    return 0 if duration_months.zero? || total_amount.blank?
    (total_amount / duration_months).round(2)
  end

  def ongoing_weekly_rate
    return 0 if weeks_in_contract.zero?
    ((total_amount - starter_cost) / weeks_in_contract).round(2)
  end

  def ongoing_monthly_rate
    return 0 if duration_months.zero?
    ((total_amount - starter_cost) / duration_months).round(2)
  end

  def expired?
    expires_at < Date.today || status == 'expired'
  end

  def needs_satellite?
    effective_collections_per_week > 1
  end

  # Returns the stored collections_per_week, falling back to the line-item qty
  # of the "Weekly collection" product if the stored value is still the default.
  def effective_collections_per_week
    return collections_per_week if collections_per_week > 1

    weekly_item = quotation_items.joins(:product)
                                 .find { |i| i.product.title.match?(/weekly collection/i) }
    weekly_item ? weekly_item.quantity.to_i : collections_per_week
  end

  # Scans product titles for "25L" or "45L" to infer bucket size.
  # Returns 25, 45, or nil if no volume processing product is on the quote.
  def inferred_bucket_size
    quotation_items.joins(:product).each do |item|
      return 25 if item.product.title.match?(/25\s*[Ll]/i)
      return 45 if item.product.title.match?(/45\s*[Ll]/i)
    end
    nil
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

  def starter_cost
    quotation_items
      .joins(:product)
      .where("products.title ILIKE ?", "%Starter%")
      .sum { |i| (i.amount || 0) * (i.quantity || 0) }
  end

  def has_customer_or_prospect_details
    if user_id.nil? && prospect_name.blank?
      errors.add(:base, "Must have either a customer or prospect name")
    end
  end
end
