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
      suburb:         suburb_fixture("Rondebosch"),
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

  # ── Stale nil total_amount ───────────────────────────────────────────────────
  # Regression: a stale invoice with nil total_amount (never recalculated) blew
  # up on `@invoice.total_amount * 100` with "nil can't be coerced into an
  # integer" — for every payment type, not just EFT.

  test "paid action recovers from a stale nil total_amount by recalculating first" do
    product = Product.create!(title: "Compost", description: "bin bags", price: 100,
                              billing_type: "standard")
    inv = Invoice.create!(subscription: @subscription, issued_date: Date.today,
                          due_date: Date.today + 14, total_amount: 0)
    inv.invoice_items.create!(product: product, quantity: 2, amount: 100) # real total: 200
    inv.update_column(:total_amount, nil) # simulate a stale/never-recalculated row

    sign_in @admin
    assert_difference "Payment.count", 1 do
      post paid_invoice_path(inv), params: { payment_type: "eft" }
    end

    assert_nil flash[:alert]
    assert inv.reload.paid
    assert_equal 200, inv.total_amount
    assert_equal 20000, Payment.last.total_amount
  end

  # ── Editing invoice items ────────────────────────────────────────────────────
  # Regression: InvoicesController#edit used to build a blank invoice_item
  # (no product) whenever the invoice had none, purely to give the form a row.
  # That row rendered with no indication it wasn't a real item, and submitting
  # it (even untouched, with quantity filled in but no product) blew up
  # #update: @invoice.update(invoice_params)'s failure was never checked, so
  # the code carried on, created the unrelated new item, and then
  # @invoice.calculate_total crashed with an uncaught RecordInvalid because
  # the still-dirty, still-invalid blank item got swept up by autosave.

  test "edit does not build a placeholder invoice item for an invoice with none" do
    inv = Invoice.create!(subscription: @subscription, issued_date: Date.today,
                          due_date: Date.today + 14, total_amount: 0)
    sign_in @admin

    get edit_invoice_path(inv)

    assert_response :success
    assert_equal 0, inv.invoice_items.size
  end

  test "update surfaces a validation error instead of crashing on an invalid nested item" do
    inv = Invoice.create!(subscription: @subscription, issued_date: Date.today,
                          due_date: Date.today + 14, total_amount: 0)
    product = Product.create!(title: "Compost", description: "bin bags", price: 720,
                              billing_type: "standard")
    sign_in @admin

    patch invoice_path(inv), params: {
      invoice: {
        invoice_items_attributes: {
          "0"     => { quantity: "1.0", product_id: "", amount: "", _destroy: "0" },
          "new_0" => { quantity: "1", product_id: product.id.to_s, amount: "720.0" }
        }
      }
    }

    assert_response :unprocessable_entity
    assert_match /could not update invoice/i, flash[:alert]
  end

  # ── Removing discount codes ──────────────────────────────────────────────────
  # Regression: remove_discount_code was missing from the set_invoice
  # before_action list, so @invoice was nil for the whole action — it 500'd on
  # `@invoice.invoice_discount_codes.find`, and even the rescue's own
  # `redirect_to edit_invoice_path(@invoice)` blew up on the nil @invoice too.

  test "admin removes a discount code and total is recalculated" do
    sign_in @admin
    code = DiscountCode.create!(code: "SAVE10", discount_percent: 10)
    inv  = discountable_invoice
    idc  = inv.invoice_discount_codes.create!(discount_code: code, discount_amount: 20)
    inv.calculate_total

    delete remove_discount_code_invoice_path(inv, invoice_discount_code_id: idc.id),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :redirect
    assert_nil flash[:alert]
    assert_not inv.invoice_discount_codes.exists?(idc.id)
    assert_equal 200, inv.reload.total_amount
  end

  # ── Discount codes ───────────────────────────────────────────────────────────
  # Regression: apply_discount_code used to call code.three_month_only?, a method
  # removed when the NEWSOIL26 promo was retired. The broad rescue turned the
  # resulting NoMethodError into an "Error applying discount code" flash and
  # broke the button for EVERY code, not just the retired one.

  def discountable_invoice
    product = Product.create!(title: "Compost", description: "bin bags", price: 100,
                              billing_type: "standard")
    inv = Invoice.create!(subscription: @subscription, issued_date: Date.today,
                          due_date: Date.today + 14, total_amount: 200)
    inv.invoice_items.create!(product: product, quantity: 2, amount: 100) # subtotal 200
    inv
  end

  test "admin applies a percentage discount code without error" do
    sign_in @admin
    code = DiscountCode.create!(code: "SAVE10", discount_percent: 10)
    inv  = discountable_invoice

    assert_difference "inv.invoice_discount_codes.count", 1 do
      post apply_discount_code_invoice_path(inv), params: { discount_code: "save10" }
    end

    assert_redirected_to invoice_path(inv)
    assert_nil flash[:alert], "should not surface an error flash"
    assert_match /applied successfully/i, flash[:notice]
    assert_equal 1, code.reload.used_count
  end

  test "admin applies a fixed-amount discount code without error" do
    sign_in @admin
    DiscountCode.create!(code: "FLAT50", discount_cents: 5000) # R50
    inv = discountable_invoice

    post apply_discount_code_invoice_path(inv), params: { discount_code: "FLAT50" }

    assert_redirected_to invoice_path(inv)
    assert_nil flash[:alert]
    assert_match /applied successfully/i, flash[:notice]
  end

  # ── Driver index — compost roll invoices only ─────────────────────────────────

  def compost_bags_product
    Product.find_or_create_by!(title: "Compost bin bags") do |p|
      p.description  = "rolls"
      p.price        = 90
      p.billing_type = "standard"
    end
  end

  test "driver index only lists invoices made up entirely of compost bin bags" do
    bags = compost_bags_product
    service = Product.create!(title: "Weekly Collection Service", description: "sub", price: 300, billing_type: "standard")

    compost_only = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0)
    compost_only.invoice_items.create!(product: bags, quantity: 1, amount: 90)

    mixed = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0)
    mixed.invoice_items.create!(product: bags, quantity: 1, amount: 90)
    mixed.invoice_items.create!(product: service, quantity: 1, amount: 300)

    subscription_only = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0)
    subscription_only.invoice_items.create!(product: service, quantity: 1, amount: 300)

    sign_in @driver
    get invoices_path

    assert_response :success
    assert_select "a[href='#{invoice_path(compost_only)}']"
    assert_select "a[href='#{invoice_path(mixed)}']", false
    assert_select "a[href='#{invoice_path(subscription_only)}']", false
  end

  test "driver index shows a paid/unpaid indicator and a whatsapp resend link" do
    bags = compost_bags_product
    unpaid = Invoice.create!(subscription: @subscription, issued_date: Date.today, due_date: Date.today + 7, total_amount: 0, paid: false)
    unpaid.invoice_items.create!(product: bags, quantity: 1, amount: 90)

    sign_in @driver
    get invoices_path

    assert_response :success
    assert_select "a[href='#{bags_whatsapp_invoice_path(unpaid)}']"
    assert_select "i.fa-circle-xmark"
  end
end
