require "test_helper"

# Covers the protein/plate-waste stream on subscriptions: the frequency validation
# and the scopes. Protein is a stream, never a plan — a protein client is
# plan: Commercial, waste_stream: protein.
class WasteStreamTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email:        "protein-#{SecureRandom.hex(4)}@example.com",
      password:     "password",
      phone_number: "+27800000010"
    )
  end

  def build_subscription(**overrides)
    Subscription.new({
      user:                   @user,
      plan:                   "Commercial",
      duration:               6,
      street_address:         "1 Test St",
      suburb:                 "Gardens",
      bucket_size:            25,
      buckets_per_collection: 2,
      collections_per_week:   3
    }.merge(overrides))
  end

  test "defaults to the general stream" do
    assert_equal "general", build_subscription.waste_stream
    assert build_subscription.general_waste_stream?
  end

  test "protein subscription with 3 collections per week is valid" do
    sub = build_subscription(waste_stream: :protein, collections_per_week: 3)

    assert sub.valid?, sub.errors.full_messages.join(", ")
    assert sub.protein_waste_stream?
  end

  test "protein subscription with 2 collections per week is valid" do
    assert build_subscription(waste_stream: :protein, collections_per_week: 2).valid?
  end

  # Collection frequency is a commercial decision, not a data rule: the first
  # protein customer is a Commercial site collected once a week.
  test "protein subscription with 1 collection per week is valid" do
    sub = build_subscription(waste_stream: :protein, collections_per_week: 1)

    assert sub.valid?, sub.errors.full_messages.join(", ")
    assert_empty sub.errors[:collections_per_week]
  end

  test "general subscription with 1 collection per week is unaffected" do
    assert build_subscription(waste_stream: :general, collections_per_week: 1).valid?
  end

  test "once_off protein is valid" do
    sub = build_subscription(plan: "once_off", duration: nil, waste_stream: :protein,
                             collections_per_week: 1)

    assert sub.valid?, sub.errors.full_messages.join(", ")
  end

  test "protein scope returns only protein subscriptions" do
    protein = build_subscription(waste_stream: :protein)
    protein.save!
    general = build_subscription(waste_stream: :general, collections_per_week: 1)
    general.save!

    assert_includes Subscription.protein, protein
    assert_not_includes Subscription.protein, general
  end

  test "the plan enum is untouched by the new stream" do
    assert_equal({ "once_off" => 0, "Standard" => 1, "XL" => 2, "Commercial" => 3 },
                 Subscription.plans,
                 "existing plan enum values must never be reordered")
  end
end
