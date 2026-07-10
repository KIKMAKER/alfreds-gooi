# frozen_string_literal: true
require "test_helper"

class SoilBagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: "Thandi", last_name: "Mokoena",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", og: false
    )

    @subscription = Subscription.create!(
      user: @user,
      street_address: "12 Rouwkoop Rd, Rondebosch",
      suburb: "Rondebosch",
      collection_day: "Tuesday",
      plan: "Standard",
      duration: 3,
      status: :active,
      start_date: Date.current - 1.week,
      latitude: -33.96, longitude: 18.48
    )

    @collection = Collection.create!(
      subscription: @subscription, date: Date.current + 3.days,
      bags: 0, buckets: 0.0, skip: false, soil_bag: 0
    )
    @token = @collection.ensure_soil_bag_token!
  end

  test "landing page renders for a logged out customer without writing anything" do
    get soil_bag_path(@token)

    assert_response :success
    assert_equal 0, @collection.reload.soil_bag, "GET must not claim a bag"
  end

  test "claiming sets soil_bag to 1 on that collection" do
    post claim_soil_bag_path(@token)

    assert_response :success
    assert_equal 1, @collection.reload.soil_bag
  end

  test "claiming twice does not stack" do
    2.times { post claim_soil_bag_path(@token) }

    assert_equal 1, @collection.reload.soil_bag
  end

  test "an unknown token is rejected" do
    get soil_bag_path("zzzzzzzz")

    assert_response :not_found
    assert_equal 0, @collection.reload.soil_bag
  end

  test "a blank token does not match a collection with a null token" do
    untokened = Collection.create!(subscription: @subscription, date: Date.current + 4.days,
                                   bags: 0, buckets: 0.0, skip: false, soil_bag: 0)
    assert_nil untokened.soil_bag_token, "sanity: collections start with no token"

    # A nil-valued finder would match this row via `WHERE soil_bag_token IS NULL`.
    get soil_bag_path("%20")

    assert_response :not_found
    assert_equal 0, untokened.reload.soil_bag
  end

  test "a token is dead once its collection date has passed" do
    @collection.update_column(:date, Date.current - 1.day)

    post claim_soil_bag_path(@token)

    assert_response :not_found
    assert_equal 0, @collection.reload.soil_bag
  end

  test "a token still works on the morning of the collection" do
    @collection.update_column(:date, Date.current)

    post claim_soil_bag_path(@token)

    assert_response :success
    assert_equal 1, @collection.reload.soil_bag
  end

  test "a revoked token is rejected without affecting other customers" do
    other = Collection.create!(subscription: @subscription, date: Date.current + 5.days,
                               bags: 0, buckets: 0.0, skip: false, soil_bag: 0)
    other_token = other.ensure_soil_bag_token!

    @collection.revoke_soil_bag_token!

    post claim_soil_bag_path(@token)
    assert_response :not_found

    post claim_soil_bag_path(other_token)
    assert_response :success
    assert_equal 1, other.reload.soil_bag
  end

  test "a token for a deleted collection is rejected rather than 500ing" do
    @collection.destroy!

    get soil_bag_path(@token)

    assert_response :not_found
  end

  test "one customer's token cannot claim another customer's bag" do
    other_collection = Collection.create!(
      subscription: @subscription, date: Date.current + 10.days,
      bags: 0, buckets: 0.0, skip: false, soil_bag: 0
    )
    other_collection.ensure_soil_bag_token!

    post claim_soil_bag_path(@token)

    assert_equal 1, @collection.reload.soil_bag
    assert_equal 0, other_collection.reload.soil_bag, "only the tokened collection is touched"
  end
end
