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
  end

  test "landing page renders for a logged out customer without writing anything" do
    get soil_bag_path(@collection.soil_bag_token)

    assert_response :success
    assert_equal 0, @collection.reload.soil_bag, "GET must not claim a bag"
  end

  test "claiming sets soil_bag to 1 on that collection" do
    post claim_soil_bag_path(@collection.soil_bag_token)

    assert_response :success
    assert_equal 1, @collection.reload.soil_bag
  end

  test "claiming twice does not stack" do
    2.times { post claim_soil_bag_path(@collection.soil_bag_token) }

    assert_equal 1, @collection.reload.soil_bag
  end

  test "a tampered token is rejected" do
    get soil_bag_path("not-a-real-token")

    assert_response :not_found
    assert_equal 0, @collection.reload.soil_bag
  end

  test "a token signed for a different purpose is rejected" do
    other_purpose = @collection.signed_id(purpose: :something_else)

    post claim_soil_bag_path(other_purpose)

    assert_response :not_found
    assert_equal 0, @collection.reload.soil_bag
  end

  test "an expired token is rejected" do
    token = @collection.soil_bag_token(expires_in: 1.minute)

    travel 2.minutes do
      post claim_soil_bag_path(token)
      assert_response :not_found
    end

    assert_equal 0, @collection.reload.soil_bag
  end

  test "a token for a deleted collection is rejected rather than 500ing" do
    token = @collection.soil_bag_token
    @collection.destroy!

    get soil_bag_path(token)

    assert_response :not_found
  end

  test "one customer's token cannot claim another customer's bag" do
    other_collection = Collection.create!(
      subscription: @subscription, date: Date.current + 10.days,
      bags: 0, buckets: 0.0, skip: false, soil_bag: 0
    )

    post claim_soil_bag_path(@collection.soil_bag_token)

    assert_equal 1, @collection.reload.soil_bag
    assert_equal 0, other_collection.reload.soil_bag, "only the signed collection is touched"
  end
end
