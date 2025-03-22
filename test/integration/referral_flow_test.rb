require "test_helper"

class ReferralFlowTest < ActionDispatch::IntegrationTest
  def setup
    # Referrer user
    @referrer = User.create!(
      first_name: "Ref",
      last_name: "User",
      email: "ref@example.com",
      phone_number: "+27836353126",
      password: "password",
      referral_code: "REF123"
    )

    # Referee user (who will use the code)
    @referee = User.create!(
      first_name: "Ree",
      last_name: "User",
      email: "ree@example.com",
      phone_number: "+27836353126",
      password: "password"
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
    @starter_kit = Product.create!(
      title: "XL Starter Kit",
      description: "Big kit",
      price: 300
    )

    @subscription_product = Product.create!(
      title: "XL 3 month subscription",
      description: "Test sub",
      price: 810
    )

  end

  test "referee signs up with referral and gets discount" do
    referee = @referee

    subscription = Subscription.create!(
      user: referee,
      plan: "XL",
      duration: 3,
      referral_code: @referrer.referral_code,
      street_address: "123 Referee Rd",
      suburb: "Cape Town"
    )

    invoice = InvoiceBuilder.new(subscription: subscription, og: nil, is_new:true, referee: @referrer, referred_friends: nil).call

    assert invoice.invoice_items.any? { |item| item.product.title == "Referral discount XL 3 month" }

    referral = Referral.find_by(referee_id: referee.id, referrer_id: @referrer.id)
    assert referral.present?, "Referral should be created"
    assert_equal "pending", referral.status
  end

  test "referrer gets discount after referee payment" do
    referee = @referee
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

    invoice = InvoiceBuilder.new(
      subscription: referrer_sub,
      og: false,
      is_new: false,
      referee: nil,
      referred_friends: 1
    ).call

    assert invoice.invoice_items.any? { |item| item.product.title == "Referred a friend discount" }
    assert_equal 760, invoice.invoice_items.sum(&:amount)
  end



end
