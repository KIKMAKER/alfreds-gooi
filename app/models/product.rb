class Product < ApplicationRecord
  BILLING_TYPES = %w[standard quote_only invoice_only].freeze

  validates :description, :title, :price, presence: true
  validates :billing_type, inclusion: { in: BILLING_TYPES }
  validate  :invoice_product_must_be_invoice_eligible, if: -> { invoice_product_id.present? }

  has_many :invoice_items,  dependent: :restrict_with_error
  has_many :quotation_items, dependent: :restrict_with_error
  has_many_attached :images

  # Self-referential: a quote_only product points to its invoice equivalent.
  # This replaces title-string resolution in InvoiceBuilder for quote-driven invoices.
  belongs_to :invoice_product, class_name: "Product", optional: true
  has_many   :quote_products,  class_name: "Product", foreign_key: :invoice_product_id

  scope :shop_items,       -> { where(is_active: true) }
  scope :in_stock,         -> { where("stock > ?", 0) }
  scope :invoice_eligible, -> { where(billing_type: %w[standard invoice_only]) }
  scope :quote_eligible,   -> { where(billing_type: %w[standard quote_only]) }
  scope :quote_only_type,  -> { where(billing_type: "quote_only") }
  scope :invoice_only,     -> { where(billing_type: "invoice_only") }

  def quote_only?   = billing_type == "quote_only"
  def invoice_only? = billing_type == "invoice_only"
  def standard?     = billing_type == "standard"

  # Returns the product that should appear on an invoice for this line item.
  # For quote_only products with a mapped invoice product, returns the mapped product.
  # For standard or invoice_only products, returns self.
  def effective_invoice_product
    quote_only? && invoice_product ? invoice_product : self
  end

  def in_stock?
    stock.to_i > 0
  end

  def out_of_stock?
    stock.to_i <= 0
  end

  def primary_image
    images.first
  end

  private

  def invoice_product_must_be_invoice_eligible
    target = Product.find_by(id: invoice_product_id)
    unless target&.billing_type.in?(%w[standard invoice_only])
      errors.add(:invoice_product, "must be a standard or invoice_only product")
    end
  end
end
