require "test_helper"

class PlanPricingTest < ActiveSupport::TestCase
  test "no code returns the plain monthly rate, undiscounted" do
    quote = PlanPricing.quote(plan: "Standard", duration: 6)

    assert_equal 180.0, quote.per_month
    assert_equal 1080.0, quote.total
    assert_not quote.discounted?
  end

  test "a referral code is a flat 15% off every duration" do
    [1, 3, 6].each do |duration|
      quote = PlanPricing.quote(plan: "Standard", duration: duration, referral_code: "ABC123")
      original = PlanPricing::MONTHLY_RATES["Standard"][duration] * duration

      assert_in_delta original * 0.85, quote.total, 0.01
      assert quote.discounted?
    end
  end

  test "NEWSOIL26 only discounts the 3-month plan" do
    quote_3mo = PlanPricing.quote(plan: "XL", duration: 3, discount_code: "NEWSOIL26", pct: 0.2)
    quote_1mo = PlanPricing.quote(plan: "XL", duration: 1, discount_code: "NEWSOIL26", pct: 0.2)
    quote_6mo = PlanPricing.quote(plan: "XL", duration: 6, discount_code: "NEWSOIL26", pct: 0.2)

    assert quote_3mo.discounted?
    assert_not quote_1mo.discounted?
    assert_not quote_6mo.discounted?
  end

  test "a percent discount code applies uniformly across durations" do
    quote = PlanPricing.quote(plan: "Standard", duration: 6, discount_code: "SAVE20", pct: 0.2)

    assert_in_delta 1080.0 * 0.8, quote.total, 0.01
    assert quote.discounted?
  end

  test "a cents-based discount code subtracts a flat amount, floored at zero" do
    quote = PlanPricing.quote(plan: "Standard", duration: 1, discount_code: "R500OFF", amt: 500.0)

    assert_equal 0.0, quote.total
  end
end
