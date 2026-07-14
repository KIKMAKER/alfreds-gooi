# frozen_string_literal: true
require "test_helper"

class DriverMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @driver = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", og: false, role: :driver
    )
    sign_in @driver

    # Target the next Tuesday, which is what the tool computes from "tuesday".
    @date = next_weekday("Tuesday")
  end

  def next_weekday(name)
    wday = Date::DAYNAMES.index(name)
    ahead = (wday - Date.today.wday) % 7
    ahead = 7 if ahead.zero?
    Date.today + ahead
  end

  def customer(plan: "Standard")
    User.create!(
      first_name: "Cust", last_name: "Omer",
      phone_number: "+2782#{rand(1_000_000..9_999_999)}", password: "password",
      email: "cust-#{SecureRandom.hex(4)}@gmail.com", og: false
    )
  end

  def subscription_for(user, plan: "Standard")
    Subscription.create!(
      user: user, street_address: "1 Test Rd, Rondebosch", suburb: "Rondebosch",
      collection_day: "Tuesday", plan: plan, duration: (plan == "once_off" ? nil : 3),
      status: :active, start_date: Date.current - 2.weeks, latitude: -33.96, longitude: 18.48
    )
  end

  def collection_on(subscription, date, **attrs)
    Collection.create!({ subscription: subscription, date: date, bags: 0, buckets: 0.0, skip: false }.merge(attrs))
  end

  # Reminder and skip invitation on separate lines, per the tool's guidance: the
  # skip line is removed for ineligible customers, leaving the reminder.
  SKIP_MSG = "Gooiday reminder!\nAway this week? Skip here: {skip_link}"
  REMINDER_ENCODED = ERB::Util.url_encode("Gooiday reminder!")

  test "the page renders" do
    get driver_messages_path
    assert_response :success
  end

  test "a returning customer gets a real skip link in their message" do
    sub = subscription_for(customer)
    2.times { |i| collection_on(sub, Date.current - (i + 1).weeks) } # veteran
    upcoming = collection_on(sub, @date)

    get driver_messages_path, params: { collection_day: "tuesday", message: SKIP_MSG }

    assert_response :success
    upcoming.reload
    assert_not_nil upcoming.skip_token, "eligible customer's token was minted"
    assert_match %r{wa\.me/[^"]*skipme%2F#{upcoming.skip_token}}, response.body
  end

  test "a once-off customer has the skip invitation removed" do
    sub = subscription_for(customer, plan: "once_off")
    collection_on(sub, @date)

    get driver_messages_path, params: { collection_day: "tuesday", message: SKIP_MSG }

    assert_response :success
    # The customer still gets the reminder line, just no skip line/link.
    assert_match %r{wa\.me/\d+\?text=#{REMINDER_ENCODED}}, response.body, "the once-off customer is still messaged"
    assert_no_match %r{skipme%2F}, response.body
  end

  test "a brand-new customer has the skip invitation removed" do
    sub = subscription_for(customer)
    upcoming = collection_on(sub, @date) # first ever collection

    get driver_messages_path, params: { collection_day: "tuesday", message: SKIP_MSG }

    assert_response :success
    assert_match %r{wa\.me/\d+\?text=#{REMINDER_ENCODED}}, response.body, "the new customer still gets the reminder"
    assert_no_match %r{skipme%2F}, response.body
    assert_nil upcoming.reload.skip_token, "no token minted for an ineligible customer"
  end

  test "a message without the placeholder mints no tokens" do
    sub = subscription_for(customer)
    2.times { |i| collection_on(sub, Date.current - (i + 1).weeks) }
    upcoming = collection_on(sub, @date)

    get driver_messages_path, params: { collection_day: "tuesday", message: "Just a friendly reminder!" }

    assert_response :success
    assert_nil upcoming.reload.skip_token
  end

  test "eligible and ineligible customers on the same day are handled independently" do
    veteran_sub = subscription_for(customer)
    2.times { |i| collection_on(veteran_sub, Date.current - (i + 1).weeks) }
    veteran_upcoming = collection_on(veteran_sub, @date)

    newbie_sub = subscription_for(customer)
    newbie_upcoming = collection_on(newbie_sub, @date)

    get driver_messages_path, params: { collection_day: "tuesday", message: SKIP_MSG }

    assert_response :success
    assert_not_nil veteran_upcoming.reload.skip_token
    assert_nil newbie_upcoming.reload.skip_token
  end
end
