require "test_helper"

# End-to-end integration tests for the customer resubscribe flow.
#
# Flow: returning customer POSTs /subscriptions with plan/duration params →
# RenewalService duplicates last sub → InvoiceBuilder creates invoice →
# suggested_start_date + adopt_future_collections! → redirect to invoice.
class ResubscribeFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name:   "Sipho",
      last_name:    "Dlamini",
      email:        "sipho-#{SecureRandom.hex(4)}@gooi.me",
      phone_number: "+27821234567",
      password:     "password",
      og:           false
    )

    @completed_sub = Subscription.create!(
      user:            @user,
      plan:            "Standard",
      duration:        1,
      status:          :completed,
      street_address:  "18 Kloof Street, Gardens",
      suburb:          "Gardens",
      collection_day:  "Thursday",
      collection_order: 5,
      start_date:      4.weeks.ago.to_date,
      end_date:        1.week.ago.to_date,
      latitude:        -33.93,
      longitude:       18.42,
      customer_id:     "GFWC#{rand(1000..9999)}"
    )

    @std_1m_product = Product.find_or_create_by!(title: "Standard 1 month subscription") do |p|
      p.price       = 220.0
      p.description = "Standard 1-month"
    end

    sign_in @user
  end

  # ── Happy path ─────────────────────────────────────────────────────────

  test "creates pending subscription and invoice, redirects to invoice" do
    assert_difference -> { @user.subscriptions.count }, 1 do
      post subscriptions_path, params: {
        subscription: { plan: "Standard", duration: 1 }
      }
    end

    new_sub = @user.subscriptions.order(created_at: :desc).first
    assert_equal "pending",  new_sub.status
    assert_equal "Standard", new_sub.plan
    assert_equal 1,          new_sub.duration
    assert_equal "Gardens",  new_sub.suburb, "copies suburb from last sub"
    assert_equal "18 Kloof Street, Gardens", new_sub.street_address, "copies street address"
    assert_equal false,      new_sub.is_new_customer

    invoice = new_sub.invoices.first
    assert_not_nil invoice
    assert_redirected_to invoice_path(invoice)
  end

  test "invoice contains the correct subscription product line item" do
    post subscriptions_path, params: {
      subscription: { plan: "Standard", duration: 1 }
    }

    new_sub = @user.subscriptions.order(created_at: :desc).first
    invoice = new_sub.invoices.first

    item = invoice.invoice_items.find_by(product: @std_1m_product)
    assert_not_nil item, "invoice must include Standard 1 month subscription product"
    assert_equal 1,     item.quantity
    assert_equal 220.0, item.amount
  end

  test "start_date is set and falls on the correct collection day" do
    post subscriptions_path, params: {
      subscription: { plan: "Standard", duration: 1 }
    }

    new_sub = @user.subscriptions.order(created_at: :desc).first
    assert_not_nil new_sub.start_date, "start_date must be persisted"
    # Gardens → Thursday (wday 4)
    assert_equal 4, new_sub.start_date.wday,
      "start_date should land on a Thursday for Gardens suburb"
  end

  # ── Early renewal ───────────────────────────────────────────────────────

  test "early renewal sets start_date to day after previous end_date aligned to collection day" do
    # Previous sub hasn't ended yet
    future_end = 1.week.from_now.to_date
    @completed_sub.update_column(:end_date, future_end)

    post subscriptions_path, params: {
      subscription: { plan: "Standard", duration: 1 }
    }

    new_sub = @user.subscriptions.order(created_at: :desc).first
    # start_date should be >= future_end + 1 and on a Thursday
    assert new_sub.start_date >= future_end,
      "early renewal start_date should be after previous end_date"
    assert_equal 4, new_sub.start_date.wday,
      "early renewal start_date must align to collection day (Thursday)"
  end

  # ── adopt_future_collections! ──────────────────────────────────────────

  test "future collection on completed subscription is adopted by new subscription" do
    # Simulates a collection pre-created for next week still sitting on the completed sub.
    # adopt_future_collections! re-assigns these so the driver sees the customer on the new sub.
    future_collection = @completed_sub.collections.create!(
      date: 2.weeks.from_now.to_date,
      skip: false
    )

    post subscriptions_path, params: {
      subscription: { plan: "Standard", duration: 1 }
    }

    new_sub = @user.subscriptions.order(created_at: :desc).first
    assert_equal new_sub.id, future_collection.reload.subscription_id,
      "future collection on completed sub should be adopted by the new subscription"
  end

  test "collection on active subscription is NOT stolen when resubscribing" do
    # Another active sub the user has (shouldn't happen often, but guard is important)
    other_active_sub = Subscription.create!(
      user:            @user,
      plan:            "Standard",
      duration:        1,
      status:          :active,
      street_address:  "55 Main Road, Observatory",
      suburb:          "Observatory",
      collection_day:  "Thursday",
      start_date:      Date.current,
      latitude:        -33.93,
      longitude:       18.47,
      customer_id:     @user.customer_id
    )
    protected_collection = Collection.create!(
      subscription: other_active_sub,
      user:         @user,
      date:         2.weeks.from_now.to_date,
      skip:         false
    )

    post subscriptions_path, params: {
      subscription: { plan: "Standard", duration: 1 }
    }

    assert_equal other_active_sub.id, protected_collection.reload.subscription_id,
      "active subscription's collections must not be stolen"
  end

  # ── Idempotency guard ──────────────────────────────────────────────────

  test "double-submit within 10 minutes redirects to existing invoice, no duplicate sub" do
    post subscriptions_path, params: {
      subscription: { plan: "Standard", duration: 1 }
    }
    first_invoice_url = response.location

    assert_no_difference -> { @user.subscriptions.count } do
      post subscriptions_path, params: {
        subscription: { plan: "Standard", duration: 1 }
      }
    end

    assert_redirected_to first_invoice_url,
      "second submit should redirect to the already-created invoice"
  end

  # ── Error cases ────────────────────────────────────────────────────────

  test "user with no previous subscription gets error, no sub created" do
    new_user = User.create!(
      first_name: "Brand", last_name: "New",
      email: "brandnew-#{SecureRandom.hex(4)}@gooi.me",
      phone_number: "+27822222222",
      password: "password"
    )
    sign_in new_user

    assert_no_difference -> { new_user.subscriptions.count } do
      post subscriptions_path, params: {
        subscription: { plan: "Standard", duration: 1 }
      }
    end

    assert_response :unprocessable_entity
    assert flash[:alert].present?, "should set a flash alert for users with no previous subscription"
  end

  test "missing product rolls back entire transaction, no orphan pending sub" do
    # The product for XL 1 month doesn't exist in test DB
    @user.update!(og: false)

    assert_no_difference -> { @user.subscriptions.count } do
      post subscriptions_path, params: {
        subscription: { plan: "XL", duration: 1 }
      }
    end

    assert_response :unprocessable_entity,
      "should render :new with 422 when InvoiceBuilder raises"
    assert_match /something went wrong/i, flash[:alert]
  end

  # ── Contact copying ────────────────────────────────────────────────────

  test "contacts are copied from previous subscription when requested" do
    contact = @completed_sub.contacts.create!(
      first_name:   "Thandi",
      last_name:    "Nkosi",
      phone_number: "+27833334444",
      relationship: "housemate",
      is_primary:   false
    )

    post subscriptions_path, params: {
      subscription: {
        plan:                         "Standard",
        duration:                     1,
        copy_contacts_from_previous:  "1",
        previous_subscription_id:     @completed_sub.id
      }
    }

    new_sub = @user.subscriptions.order(created_at: :desc).first
    copied = new_sub.contacts.find_by(phone_number: "+27833334444")
    assert_not_nil copied, "partner contact should be copied to new subscription"
    assert_equal "Thandi", copied.first_name
  end

  test "contacts are NOT copied when copy_contacts_from_previous is 0" do
    @completed_sub.contacts.create!(
      first_name:   "Thandi",
      last_name:    "Nkosi",
      phone_number: "+27833334444",
      relationship: "housemate",
      is_primary:   false
    )

    post subscriptions_path, params: {
      subscription: {
        plan:                        "Standard",
        duration:                    1,
        copy_contacts_from_previous: "0",
        previous_subscription_id:   @completed_sub.id
      }
    }

    new_sub = @user.subscriptions.order(created_at: :desc).first
    assert_empty new_sub.contacts.where(phone_number: "+27833334444"),
      "contacts should not be copied when flag is 0"
  end
end
