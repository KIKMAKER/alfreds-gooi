require "test_helper"

# A protein quote must convert into a protein subscription. Protein is decided by
# the products on the quote (there is no protein plan), so the conversion reads the
# stream off the quote's line items rather than trusting the form alone.
class ProteinQuoteToSubscriptionTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Alfred", last_name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@gooi.me",
      phone_number: "+27821110001", password: "password", role: :admin
    )

    @customer = User.create!(
      first_name: "Nina", last_name: "Restaurateur",
      email: "nina-#{SecureRandom.hex(4)}@gooi.me",
      phone_number: "+27765486400", password: "password"
    )

    @protein_volume = Product.create!(
      title: "Protein Volume Processing per 25L (6-month rate)", price: 1300,
      description: "Protein volume processing", billing_type: "standard"
    )
    @protein_visit = Product.create!(
      title: "Protein collection visit (6-month rate @ R240pm)", price: 1440,
      description: "Protein collection visit", billing_type: "standard"
    )
    @protein_bucket = Product.create!(
      title: "Protein Starter Bucket (25L sealed, swap pair)", price: 320,
      description: "Sealed swap buckets", billing_type: "standard"
    )
    @general_product = Product.create!(
      title: "Weekly collection (6-month rate @ R220pm)", price: 1320,
      description: "Weekly collection", billing_type: "standard"
    )

    sign_in @admin
  end

  def build_quotation(products:, collections_per_week: 3)
    quotation = Quotation.create!(
      user: @customer, created_date: Date.today, expires_at: Date.today + 30.days,
      duration_months: 6, collections_per_week: collections_per_week, status: :accepted
    )
    products.each { |p| quotation.quotation_items.create!(product: p, quantity: 1, amount: p.price) }
    quotation.calculate_total
    quotation
  end

  def subscription_params(**overrides)
    {
      plan: "Commercial", duration: 6,
      street_address: "18 Kloof Street, Gardens", suburb: "Gardens",
      bucket_size: 25, buckets_per_collection: 2, collections_per_week: 3,
      title: "Nina's Kitchen"
    }.merge(overrides)
  end

  # ── The quote builder can express a protein quote ───────────────────────

  test "a quote with protein products infers the protein stream" do
    quotation = build_quotation(products: [@protein_volume, @protein_visit, @protein_bucket])

    assert_equal "protein", quotation.inferred_waste_stream
    assert_equal 3, quotation.effective_collections_per_week
    assert_equal 25, quotation.inferred_bucket_size
  end

  test "a quote without protein products stays general" do
    assert_equal "general", build_quotation(products: [@general_product]).inferred_waste_stream
  end

  # ── Prefill ─────────────────────────────────────────────────────────────

  test "new subscription form preselects the protein stream from the quote" do
    quotation = build_quotation(products: [@protein_volume, @protein_visit])

    get new_admin_subscription_path(user_id: @customer.id, quotation_id: quotation.id)

    assert_response :success
    assert_select "select#subscription_waste_stream option[value='protein'][selected]", count: 1
  end

  # ── Conversion carries the stream ───────────────────────────────────────

  test "converting a protein quote sets waste_stream on the subscription" do
    quotation = build_quotation(products: [@protein_volume, @protein_visit, @protein_bucket])

    post admin_subscriptions_path, params: {
      user_id: @customer.id, quotation_id: quotation.id,
      subscription: subscription_params(waste_stream: "protein")
    }

    sub = @customer.subscriptions.order(:created_at).last
    assert sub.protein_waste_stream?, "protein quote must convert into a protein subscription"
    assert_equal "Commercial", sub.plan, "protein is a stream, not a plan"
    assert_equal 3, sub.collections_per_week
  end

  test "the quote wins even if the form omits waste_stream" do
    quotation = build_quotation(products: [@protein_volume])

    post admin_subscriptions_path, params: {
      user_id: @customer.id, quotation_id: quotation.id,
      subscription: subscription_params # no waste_stream key at all
    }

    assert @customer.subscriptions.order(:created_at).last.protein_waste_stream?
  end

  test "a satellite subscription inherits the protein stream" do
    quotation = build_quotation(products: [@protein_volume])

    post admin_subscriptions_path, params: {
      user_id: @customer.id, quotation_id: quotation.id,
      second_collection_day: "Thursday",
      subscription: subscription_params(waste_stream: "protein")
    }

    satellite = @customer.subscriptions.find { |s| s.satellite? }
    assert_not_nil satellite, "second collection day creates a satellite"
    assert satellite.protein_waste_stream?, "the satellite runs the same stream"
  end

  # ── Once-a-week protein ─────────────────────────────────────────────────

  # The first protein customer is a Commercial site collected once a week, so
  # frequency is a commercial decision rather than something the model enforces.
  test "a protein quote at 1 collection per week converts" do
    quotation = build_quotation(products: [@protein_volume], collections_per_week: 1)

    assert_difference -> { @customer.subscriptions.count }, 1 do
      post admin_subscriptions_path, params: {
        user_id: @customer.id, quotation_id: quotation.id,
        subscription: subscription_params(waste_stream: "protein", collections_per_week: 1)
      }
    end

    sub = @customer.subscriptions.order(:created_at).last
    assert sub.protein_waste_stream?
    assert_equal 1, sub.collections_per_week
  end

  # Enum assignment raises ArgumentError on an unknown value, so an unsanitised
  # param would 500 rather than fall back.
  test "an unknown waste_stream param does not 500" do
    quotation = build_quotation(products: [@general_product])

    post admin_subscriptions_path, params: {
      user_id: @customer.id, quotation_id: quotation.id,
      subscription: subscription_params(waste_stream: "nonsense")
    }

    assert_response :redirect
    assert @customer.subscriptions.order(:created_at).last.general_waste_stream?
  end
end
