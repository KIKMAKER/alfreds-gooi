require "test_helper"

class InvoiceRevenueRecognitionHookTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "rev-hook-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      phone_number: "+27800000004"
    )
    @subscription = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 3,
      street_address: "1 Test St",
      suburb: "Rondebosch"
    )
  end

  test "creating an invoice produces recognition rows immediately" do
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Date.new(2026, 5, 1),
      due_date: Date.new(2026, 5, 15),
      total_amount: 600.0
    )

    assert_equal 3, invoice.revenue_recognitions.count
    assert_in_delta 600.0, invoice.revenue_recognitions.sum(:recognized_amount).to_f, 0.005
  end

  test "recognition rows are unpaid-inclusive (accrual, not cash)" do
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Date.today,
      due_date: Date.today + 14,
      total_amount: 300.0,
      paid: false
    )

    assert invoice.revenue_recognitions.any?
  end

  test "changing the total resyncs recognition rows" do
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Date.new(2026, 5, 1),
      due_date: Date.new(2026, 5, 15),
      total_amount: 300.0
    )
    invoice.update!(total_amount: 900.0)

    assert_equal 3, invoice.revenue_recognitions.count
    assert_in_delta 900.0, invoice.revenue_recognitions.sum(:recognized_amount).to_f, 0.005
  end

  test "calculate_total after adding items leaves rows matching the final total" do
    product = Product.create!(title: "Standard 3 month subscription", price: 450.0, description: "sub", billing_type: "standard")
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Date.new(2026, 5, 1),
      due_date: Date.new(2026, 5, 15),
      total_amount: 0
    )
    invoice.invoice_items.create!(product: product, quantity: 1, amount: 450.0)
    invoice.calculate_total

    assert_in_delta 450.0, invoice.reload.revenue_recognitions.sum(:recognized_amount).to_f, 0.005
  end
end
