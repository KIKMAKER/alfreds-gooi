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
      suburb: suburb_fixture("Rondebosch")
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

  # --- compost_rolls_only scope ---

  test "compost_rolls_only includes an invoice made up only of compost bin bags" do
    bags = Product.create!(title: "Compost bin bags", description: "rolls", price: 90, billing_type: "standard")
    invoice = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0)
    invoice.invoice_items.create!(product: bags, quantity: 1, amount: 90)

    assert_includes Invoice.compost_rolls_only, invoice
  end

  test "compost_rolls_only excludes a mixed invoice that also has bags" do
    bags = Product.create!(title: "Compost bin bags", description: "rolls", price: 90, billing_type: "standard")
    service = Product.create!(title: "Weekly Collection Service", description: "sub", price: 300, billing_type: "standard")
    invoice = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0)
    invoice.invoice_items.create!(product: bags, quantity: 1, amount: 90)
    invoice.invoice_items.create!(product: service, quantity: 1, amount: 300)

    assert_not_includes Invoice.compost_rolls_only, invoice
  end

  test "compost_rolls_only excludes an invoice with no compost bags" do
    service = Product.create!(title: "Weekly Collection Service", description: "sub", price: 300, billing_type: "standard")
    invoice = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0)
    invoice.invoice_items.create!(product: service, quantity: 1, amount: 300)

    assert_not_includes Invoice.compost_rolls_only, invoice
  end
end
