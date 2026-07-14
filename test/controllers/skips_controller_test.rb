# frozen_string_literal: true
require "test_helper"

class SkipsControllerTest < ActionDispatch::IntegrationTest
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
      bags: 0, buckets: 0.0, skip: false
    )
    @token = @collection.ensure_skip_token!
  end

  test "confirm page renders for a logged out customer without skipping anything" do
    get skip_path(@token)

    assert_response :success
    assert_not @collection.reload.skip, "GET must not skip"
  end

  test "confirming skips the collection, emails, and redirects" do
    assert_emails 1 do
      post confirm_skip_path(@token)
    end

    assert_redirected_to skip_path(@token)
    assert @collection.reload.skip

    follow_redirect!
    assert_response :success
    assert_match(/we'll skip you/i, response.body)
  end

  test "confirming twice does not send a second skip email" do
    assert_emails 1 do
      2.times { post confirm_skip_path(@token) }
    end

    assert @collection.reload.skip
  end

  test "revisiting after skipping shows the calmer already-skipped message" do
    post confirm_skip_path(@token)
    follow_redirect! # consumes the just_skipped flash, as Turbo does in the browser

    get skip_path(@token)
    assert_response :success
    assert_match(/already skipped/i, response.body)
    assert_no_match(/we'll skip you/i, response.body)
  end

  test "an unknown token is rejected" do
    get skip_path("zzzzzzzz")

    assert_response :not_found
  end

  test "a skip token that has passed its collection date is dead" do
    @collection.update_column(:date, Date.current - 1.day)

    post confirm_skip_path(@token)

    assert_response :not_found
    assert_not @collection.reload.skip
  end

  test "a soil bag token cannot be used to skip" do
    soil_token = @collection.ensure_soil_bag_token!

    post confirm_skip_path(soil_token)

    assert_response :not_found
    assert_not @collection.reload.skip
  end

  test "one customer's skip token cannot skip another customer's collection" do
    other = Collection.create!(subscription: @subscription, date: Date.current + 5.days,
                               bags: 0, buckets: 0.0, skip: false)
    other.ensure_skip_token!

    post confirm_skip_path(@token)

    assert @collection.reload.skip
    assert_not other.reload.skip, "only the tokened collection is skipped"
  end
end
