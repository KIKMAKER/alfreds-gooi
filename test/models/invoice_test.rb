require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "invoice-model-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      phone_number: "+27800000001"
    )
    @subscription = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 1,
      street_address: "1 Test St",
      suburb: "Rondebosch"
    )
  end

  # --- for_order? helper ---

  test "for_order? returns false when order_id is nil" do
    invoice = Invoice.new(subscription: @subscription)
    assert_not invoice.for_order?
  end

  test "for_order? returns true when order_id is present" do
    order = Order.create!(user: @user, status: :pending)
    invoice = Invoice.new(subscription: @subscription, order: order)
    assert invoice.for_order?
  end

  # --- association ---

  test "invoice belongs to order (optional)" do
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Date.today,
      due_date: Date.today + 7,
      total_amount: 100
    )
    assert_nil invoice.order
  end

  test "invoice can be linked to an order" do
    order = Order.create!(user: @user, status: :pending)
    invoice = Invoice.create!(
      subscription: @subscription,
      order: order,
      issued_date: Date.today,
      due_date: Date.today + 7,
      total_amount: 100
    )
    assert_equal order, invoice.reload.order
  end
end
