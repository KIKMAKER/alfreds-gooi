class DiscountCode < ApplicationRecord

  def available?
    Date.today < expires_at
  end
end
