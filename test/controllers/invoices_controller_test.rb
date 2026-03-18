require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    # A driver is required by CreateFirstCollectionJob internals
    @driver = User.find_or_create_by!(email: "driver@gooi.com") do |u|
      u.first_name = "Alfred"
      u.last_name  = "Mbonjwa"
      u.password   = "password"
      u.role       = :driver
      u.phone_number = "+27785325513"
    end

    @admin = User.create!(
      email:        "admin-inv-#{SecureRandom.hex(4)}@example.com",
      password:     "password",
      role:         :admin,
      phone_number: "+27800010001"
    )

    @customer = User.create!(
      email:        "cust-inv-#{SecureRandom.hex(4)}@example.com",
      password:     "password",
      phone_number: "+27800010002"
    )

    @subscription = Subscription.create!(
      user:           @customer,
      plan:           "Standard",
      duration:       1,
      street_address: "1 Test St",
      suburb:         "Rondebosch",
      status:         :pending
    )

    @invoice = Invoice.create!(
      subscription: @subscription,
      issued_date:  Date.today,
      due_date:     Date.today + 14,
      total_amount: 660,
      paid:         false
    )
  end

  # ── Authorization ────────────────────────────────────────────────────────────

  test "non-admin cannot mark invoice paid" do
    sign_in @customer
    assert_no_difference "Payment.count" do
      post paid_invoice_path(@invoice), params: { payment_type: "eft" }
    end
    assert_redirected_to invoice_path(@invoice)
    assert_match /not authorised/i, flash[:alert]
    assert_not @invoice.reload.paid
  end

  test "unauthenticated user is redirected away" do
    assert_no_difference "Payment.count" do
      post paid_invoice_path(@invoice), params: { payment_type: "eft" }
    end
    # Devise redirects to sign-in
    assert_response :redirect
    assert_not @invoice.reload.paid
  end

  # ── Happy path — subscription invoice ────────────────────────────────────────

  test "admin marking EFT payment creates Payment record with correct attributes" do
    sign_in @admin
    assert_difference "Payment.count", 1 do
      post paid_invoice_path(@invoice), params: { payment_type: "eft" }
    end

    payment = Payment.last
    assert_equal @customer,   payment.user
    assert_equal @invoice,    payment.invoice
    assert                    payment.manual
    assert                    payment.eft?
    assert_equal 66000,       payment.total_amount  # 660 * 100 = cents
  end

  test "admin marking cash payment sets payment_type to cash" do
    sign_in @admin
    post paid_invoice_path(@invoice), params: { payment_type: "cash" }
    assert Payment.last.cash?
  end

  test "admin marking snapscan payment sets payment_type to snapscan" do
    sign_in @admin
    post paid_invoice_path(@invoice), params: { payment_type: "snapscan" }
    assert Payment.last.snapscan?
  end

  test "admin marking other payment sets payment_type to other" do
    sign_in @admin
    post paid_invoice_path(@invoice), params: { payment_type: "other" }
    assert Payment.last.other?
  end

  test "paid action marks invoice as paid" do
    sign_in @admin
    post paid_invoice_path(@invoice), params: { payment_type: "eft" }
    assert @invoice.reload.paid
  end

  test "paid action redirects to invoice with success notice" do
    sign_in @admin
    post paid_invoice_path(@invoice), params: { payment_type: "eft" }
    assert_redirected_to invoice_path(@invoice)
    assert_match /EFT/i, flash[:notice]
  end

  test "paid action on subscription invoice activates pending subscription" do
    sign_in @admin
    post paid_invoice_path(@invoice), params: { payment_type: "eft" }
    assert @subscription.reload.active?
  end

  # ── Order invoice — subscriptions must NOT be activated ───────────────────────

  test "paid action on order invoice does not activate pending subscription" do
    order   = Order.create!(user: @customer, status: :paid)
    inv     = Invoice.create!(
      subscription: @subscription,
      order:        order,
      issued_date:  Date.today,
      due_date:     Date.today + 7,
      total_amount: 150
    )

    sign_in @admin
    assert_difference "Payment.count", 1 do
      post paid_invoice_path(inv), params: { payment_type: "cash" }
    end

    assert inv.reload.paid
    assert_equal :pending, @subscription.reload.status.to_sym, "Order payment must not activate the subscription"
  end

  test "paid action on order invoice still creates Payment record" do
    order = Order.create!(user: @customer, status: :paid)
    inv   = Invoice.create!(
      subscription: @subscription,
      order:        order,
      issued_date:  Date.today,
      due_date:     Date.today + 7,
      total_amount: 150
    )

    sign_in @admin
    post paid_invoice_path(inv), params: { payment_type: "cash" }

    payment = Payment.last
    assert payment.manual
    assert payment.cash?
    assert_equal @customer, payment.user
  end

  # ── Idempotency / edge cases ─────────────────────────────────────────────────

  test "paid action with no payment_type param still succeeds" do
    sign_in @admin
    assert_difference "Payment.count", 1 do
      post paid_invoice_path(@invoice)
    end
    assert @invoice.reload.paid
    assert_nil Payment.last.payment_type
    assert_match /manual/i, flash[:notice]
  end
end
