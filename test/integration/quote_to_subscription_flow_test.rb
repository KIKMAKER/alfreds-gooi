require "test_helper"

# Integration tests for the quote → subscription → invoice conversion flow.
#
# Regression coverage for the quote #169 / invoice #851 bug: a validation
# failure on admin/subscriptions#create re-rendered the form without
# @quotation, dropping the hidden quotation_id field, so the resubmitted
# form built the invoice from the Commercial rate card instead of the
# agreed quote amounts.
class QuoteToSubscriptionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name:   "Alfred",
      last_name:    "Admin",
      email:        "admin-#{SecureRandom.hex(4)}@gooi.me",
      phone_number: "+27821110000",
      password:     "password",
      role:         :admin
    )

    @customer = User.create!(
      first_name:   "Brandon",
      last_name:    "McCormack",
      email:        "brandon-#{SecureRandom.hex(4)}@gooi.me",
      phone_number: "+27765486404",
      password:     "password"
    )

    @collection_fee = Product.create!(
      title: "Commercial collection fee (6-month)", price: 220,
      description: "Weekly commercial collection", billing_type: "invoice_only"
    )
    @volume_45 = Product.create!(
      title: "Commercial volume per 45L bucket", price: 153,
      description: "Volume processing per 45L bucket", billing_type: "invoice_only"
    )
    @weekly_quote_product = Product.create!(
      title: "Weekly collection (6-month rate @ R220pm)", price: 1320,
      description: "Weekly collection over 6 months", billing_type: "quote_only",
      invoice_product: @collection_fee
    )
    @volume_quote_product = Product.create!(
      title: "Volume Processing per 45L (Premium 6-month rate)", price: 540,
      description: "Volume processing, premium rate", billing_type: "quote_only",
      invoice_product: @volume_45
    )

    @quotation = Quotation.create!(
      user:            @customer,
      created_date:    Date.today,
      expires_at:      Date.today + 30.days,
      duration_months: 6,
      status:          :accepted
    )
    @quotation.quotation_items.create!(product: @weekly_quote_product, quantity: 2, amount: 1320)
    @quotation.quotation_items.create!(product: @volume_quote_product, quantity: 4, amount: 540)
    @quotation.calculate_total

    sign_in @admin
  end

  def valid_subscription_params
    {
      plan:                   "Commercial",
      duration:               6,
      street_address:         "18 Kloof Street, Gardens",
      suburb:                 "Gardens",
      bucket_size:            45,
      buckets_per_collection: 2,
      collections_per_week:   2,
      title:                  "Kitchen Republik",
      is_new_customer:        "1"
    }
  end

  # ── Happy path ─────────────────────────────────────────────────────────

  test "quote-driven create builds the invoice from the quoted amounts" do
    assert_difference -> { @customer.subscriptions.count } => 1, -> { Invoice.count } => 1 do
      post admin_subscriptions_path, params: {
        user_id:      @customer.id,
        quotation_id: @quotation.id,
        subscription: valid_subscription_params
      }
    end

    sub = @customer.subscriptions.order(:created_at).last
    assert_equal @quotation.id, sub.quotation_id

    invoice = sub.invoices.first
    assert_equal 4800, invoice.total_amount, "invoice total must match the quote total"

    fee_item = invoice.invoice_items.find_by(product: @collection_fee)
    assert_not_nil fee_item, "weekly collection maps to its invoice product"
    assert_equal 2,    fee_item.quantity
    assert_equal 1320, fee_item.amount

    volume_item = invoice.invoice_items.find_by(product: @volume_45)
    assert_not_nil volume_item, "volume processing maps to its invoice product"
    assert_equal 4,   volume_item.quantity
    assert_equal 540, volume_item.amount
  end

  # ── Regression: quote link must survive a validation failure ───────────

  test "validation-failure re-render keeps the hidden quotation_id field" do
    post admin_subscriptions_path, params: {
      user_id:      @customer.id,
      quotation_id: @quotation.id,
      subscription: valid_subscription_params.merge(street_address: "")
    }

    assert_response :unprocessable_entity
    assert_select "input[type=hidden][name=quotation_id][value=?]", @quotation.id.to_s,
                  { count: 1 },
                  "re-rendered form must keep the quote link or the resubmit falls back to rate-card pricing"
  end

  test "resubmitting after a validation failure still bills from the quote" do
    post admin_subscriptions_path, params: {
      user_id:      @customer.id,
      quotation_id: @quotation.id,
      subscription: valid_subscription_params.merge(street_address: "")
    }
    assert_response :unprocessable_entity

    post admin_subscriptions_path, params: {
      user_id:      @customer.id,
      quotation_id: @quotation.id,
      subscription: valid_subscription_params
    }

    invoice = @customer.subscriptions.order(:created_at).last.invoices.first
    assert_equal 4800, invoice.total_amount
  end

  # ── Guard: unresolvable quotation must not silently fall back ──────────

  test "aborts creation when quotation_id does not resolve" do
    assert_no_difference -> { Subscription.count }, -> { Invoice.count } do
      post admin_subscriptions_path, params: {
        user_id:      @customer.id,
        quotation_id: 999_999,
        subscription: valid_subscription_params
      }
    end

    assert_redirected_to admin_user_path(@customer)
    assert_match(/not found/, flash[:alert])
  end

  # ── Prefill: quote's collections per week must reach the form ──────────

  test "new form preselects collections_per_week from the quote" do
    get new_admin_subscription_path(user_id: @customer.id, quotation_id: @quotation.id)

    assert_response :success
    assert_select "select#subscription_collections_per_week option[value='2'][selected]",
                  { count: 1 },
                  "quote has 2 weekly collections; hardcoded selected: 1 must not override it"
  end
end
