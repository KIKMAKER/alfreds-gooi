require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "order-model-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      phone_number: "+27800000003"
    )
    @subscription = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 1,
      street_address: "1 Test St",
      suburb: "Rondebosch"
    )
  end

  test "order has one invoice" do
    order = Order.create!(user: @user, status: :pending)
    assert_nil order.invoice

    invoice = Invoice.create!(
      subscription: @subscription,
      order: order,
      issued_date: Date.today,
      due_date: Date.today + 7,
      total_amount: 200
    )

    assert_equal invoice, order.reload.invoice
  end
end
