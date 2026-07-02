require "test_helper"

class QuotationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      first_name: "Quote",
      last_name: "Customer",
      email: "quote_customer@example.com",
      phone_number: "+27836353126",
      password: "password"
    )

    @product = Product.create!(
      title: "Commercial collection fee (6-month)",
      description: "Weekly collection",
      price: 220
    )

    @quotation = Quotation.create!(
      user: @user,
      created_date: Date.today,
      expires_at: Date.today + 30.days,
      collections_per_week: 1
    )

    @quotation.quotation_items.create!(product: @product, quantity: 2, amount: 220)
  end

  test "billable_items returns the quotation's line items with products preloaded" do
    items = @quotation.billable_items

    assert_equal @quotation.quotation_items.to_a, items.to_a
    assert_equal @product, items.first.product
  end

  test "created_subscription is nil when no subscription references this quote" do
    assert_nil @quotation.created_subscription
  end

  test "created_subscription finds the subscription created from this quote" do
    subscription = Subscription.create!(
      user: @user,
      plan: "Commercial",
      duration: 6,
      street_address: "1 Main Road",
      suburb: Subscription::TUESDAY_SUBURBS.first,
      buckets_per_collection: 2,
      quotation_id: @quotation.id
    )

    assert_equal subscription, @quotation.created_subscription
  end
end
