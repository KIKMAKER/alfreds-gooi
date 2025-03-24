class DiscountCode < ApplicationRecord

  def available?
    not_expired = expires_at.nil? || Date.today <= expires_at.to_date
    under_limit = usage_limit.nil? || used_count < usage_limit
    not_expired && under_limit
  end
end
