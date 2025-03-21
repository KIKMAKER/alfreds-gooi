require "test_helper"

class ReferralTest < ActiveSupport::TestCase
  def setup
    # Products
    @starter_kit = Product.create!(
      title: "XL Starter Kit",
      description: "Big kit",
      price: 300
    )

    @discount = Product.create!(
      title: "Referral discount XL 3 month",
      description: "Referred discount",
      price: -122
    )

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

    # Subscription with referral code applied
    @subscription = Subscription.create!(
      user: @referee,
      plan: "XL",
      duration: 3,
      referral_code: @referrer.referral_code,
      street_address: "123 Bree Street",
      suburb: "Cape Town"
    )
  end

  test "should be valid with all associations" do
    assert @referral.valid?
  end

  test "should default to pending" do
    @referral.save
    assert_equal "pending", @referral.status
  end

  test "referee invoice includes referral discount and starter kit" do
    invoice = create_invoice_for_subscription(@subscription, nil, true, @referrer, nil)

    assert_equal 3, invoice.invoice_items.count
    titles = invoice.invoice_items.map { |item| item.product.title }

    assert_includes titles, "XL Starter Kit"
    assert_includes titles, "Referral discount XL 3 month"
  end

  test "can transition to completed and used" do
    @referral.save
    @referral.completed!
    assert_equal "completed", @referral.status

    @referral.used!
    assert_equal "used", @referral.status
  end
end
