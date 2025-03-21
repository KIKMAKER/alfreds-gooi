require "test_helper"

class ReferralFlowTest < ActionDispatch::IntegrationTest
  def setup
    @referrer = User.create!(
      email: "referrer@example.com",
      password: "password",
      referral_code: "GOOIREF"
    )

    @discount = Product.create!(
      title: "Referral discount XL 3 month",
      description: "15% off",
      price: -122
    )

    @referral_bonus = Product.create!(
      title: "Referred a friend discount",
      description: "R50 off",
      price: -50
    )

    @subscription_product = Product.create!(
      title: "XL 3 month subscription",
      description: "Test sub",
      price: 810
    )
  end

  test "referee signs up with referral and gets discount" do
    referee = User.create!(email: "referee@example.com", password: "password")

    subscription = Subscription.create!(
      user: referee,
      plan: "XL",
      duration: 3,
      referral_code: @referrer.referral_code,
      street_address: "123 Referee Rd",
      suburb: "Cape Town"
    )

    invoice = create_invoice_for_subscription(subscription, nil, true, @referrer, nil)

    assert invoice.invoice_items.any? { |item| item.product.title == "Referral discount XL 3 month" }

    referral = Referral.find_by(referee_id: referee.id, referrer_id: @referrer.id)
    assert referral.present?, "Referral should be created"
    assert_equal "pending", referral.status
  end

  test "referrer gets discount after referee payment" do
    referee = User.create!(email: "referee2@example.com", password: "password")
    referee_sub = Subscription.create!(
      user: referee,
      plan: "XL",
      duration: 3,
      referral_code: @referrer.referral_code,
      street_address: "123 Gooi Ave",
      suburb: "Cape Town"
    )
    Referral.create!(
      referrer: @referrer,
      referee: referee,
      subscription: referee_sub,
      status: :completed
    )

    referrer_sub = Subscription.create!(
      user: @referrer,
      plan: "XL",
      duration: 3,
      street_address: "456 Gooi Blvd",
      suburb: "Cape Town"
    )

    invoice = create_invoice_for_subscription(referrer_sub, false, false, nil, 1)

    assert invoice.invoice_items.any? { |item| item.product.title == "Referred a friend discount" }
    assert_equal -50, invoice.invoice_items.sum(&:amount)
  end
end
