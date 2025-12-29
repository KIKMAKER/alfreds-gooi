class DiscountCode < ApplicationRecord
  has_many :invoice_discount_codes, dependent: :destroy
  has_many :invoices, through: :invoice_discount_codes

  def available?
    not_expired = expires_at.nil? || Date.today <= expires_at.to_date
    under_limit = usage_limit.nil? || used_count < usage_limit
    not_expired && under_limit
  end

  def percentage_based?
    discount_percent.present?
  end

  def fixed_amount?
    discount_cents.present?
  end

  # Temporary: Restrict NEWSOIL26 to 3-month plans only
  def three_month_only?
    code == "NEWSOIL26"
  end
end
