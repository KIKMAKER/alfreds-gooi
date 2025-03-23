require "test_helper"

class DiscountCodeTest < ActiveSupport::TestCase
  test "code is available when under usage limit and before expiry" do
    code = DiscountCode.create!(
      code: "TEST10",
      discount_cents: 1000,
      usage_limit: 5,
      used_count: 2,
      expires_at: 1.day.from_now
    )

    assert code.available?
  end

  test "code is unavailable after expiry" do
    code = DiscountCode.create!(
      code: "TEST10",
      discount_cents: 1000,
      usage_limit: 5,
      used_count: 2,
      expires_at: 1.day.ago
    )

    refute code.available?
  end

  test "code is unavailable after hitting usage limit" do
    code = DiscountCode.create!(
      code: "TEST10",
      discount_cents: 1000,
      usage_limit: 3,
      used_count: 3,
      expires_at: 1.day.from_now
    )

    refute code.available?
  end
end
