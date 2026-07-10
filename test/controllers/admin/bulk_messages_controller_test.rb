# frozen_string_literal: true
require "test_helper"

class Admin::BulkMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Kiki", last_name: "Kennedy",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "admin-#{SecureRandom.hex(3)}@gmail.com", og: false,
      role: :admin
    )

    @customer = User.create!(
      first_name: "Thandi", last_name: "Mokoena",
      phone_number: "+2782111#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", og: false
    )

    @subscription = Subscription.create!(
      user: @customer,
      street_address: "12 Rouwkoop Rd, Rondebosch",
      suburb: "Rondebosch",
      collection_day: "Tuesday",
      plan: "Standard",
      duration: 3,
      status: :active,
      start_date: Date.current - 1.week,
      latitude: -33.96, longitude: 18.48
    )

    @collection_date = Date.current + 3.days
    @collection = Collection.create!(
      subscription: @subscription, date: @collection_date,
      bags: 0, buckets: 0.0, skip: false, soil_bag: 0
    )

    sign_in @admin
  end

  test "index renders" do
    get admin_bulk_messages_path
    assert_response :success
  end

  test "non-admins are turned away" do
    sign_in @customer
    get admin_bulk_messages_path
    assert_redirected_to root_path
  end

  test "soil_bag_link resolves to a signed claim url when filtered by collection date" do
    get admin_bulk_messages_path, params: {
      collection_date: @collection_date.to_s,
      message: "Free compost! {soil_bag_link}"
    }

    assert_response :success
    # The personalised message is URL-encoded into the wa.me href, so "/" escapes.
    assert_match %r{wa\.me/[^"]*soil-bag%2F}, response.body,
                 "claim link should appear in the WhatsApp message"
  end

  test "soil_bag_link substitutes to nothing when no collection date filter is set" do
    get admin_bulk_messages_path, params: { message: "Free compost! {soil_bag_link}" }

    assert_response :success
    assert_no_match %r{wa\.me/[^"]*soil-bag%2F}, response.body
    assert_match %r{wa\.me/}, response.body, "the message still sends, just without a link"
  end

  test "browsing the page without asking for a link does not mint tokens" do
    get admin_bulk_messages_path, params: {
      collection_date: @collection_date.to_s,
      message: "Hi {first_name}, see you {collection_day}!"
    }

    assert_response :success
    assert_nil @collection.reload.soil_bag_token
  end

  test "the minted token is stable across repeated sends" do
    2.times do
      get admin_bulk_messages_path, params: {
        collection_date: @collection_date.to_s,
        message: "Free compost! {soil_bag_link}"
      }
    end

    assert_response :success
    token = @collection.reload.soil_bag_token
    assert_match %r{soil-bag%2F#{token}}, response.body
  end

  test "a contact with no collection on the filtered date does not break the page" do
    other_sub = Subscription.create!(
      user: @customer,
      street_address: "9 Main Rd, Kalk Bay",
      suburb: "Kalk Bay",
      collection_day: "Tuesday",
      plan: "Standard",
      duration: 3,
      status: :active,
      start_date: Date.current - 1.week,
      latitude: -34.12, longitude: 18.44
    )
    Collection.create!(subscription: other_sub, date: @collection_date + 7.days,
                       bags: 0, buckets: 0.0, skip: false, soil_bag: 0)

    get admin_bulk_messages_path, params: {
      collection_date: @collection_date.to_s,
      message: "Free compost! {soil_bag_link}"
    }

    assert_response :success
  end
end
