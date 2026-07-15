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

    @date = next_weekday("Tuesday")

    # Distinctive templates so we can tell which one each recipient received.
    DriverMessageTemplate.create!(segment: "standard",     body: "STD {first_name}! Skip: {skip_link}")
    DriverMessageTemplate.create!(segment: "new_customer", body: "NEW welcome {first_name}!")
    DriverMessageTemplate.create!(segment: "once_off",     body: "ONCE {first_name}, thanks for trying us!")
    DriverMessageTemplate.create!(segment: "commercial",   body: "COMM {first_name}, bins out please.")
  end

  def next_weekday(name)
    wday = Date::DAYNAMES.index(name)
    ahead = (wday - Date.today.wday) % 7
    ahead = 7 if ahead.zero?
    Date.today + ahead
  end

  def customer
    User.create!(
      first_name: "Thandi", last_name: "Omer",
      phone_number: "+2782#{rand(1_000_000..9_999_999)}", password: "password",
      email: "cust-#{SecureRandom.hex(4)}@gmail.com", og: false
    )
  end

  def subscription_for(user, plan: "Standard")
    attrs = {
      user: user, street_address: "1 Test Rd, Rondebosch", suburb: "Rondebosch",
      collection_day: "Tuesday", plan: plan, duration: (plan == "once_off" ? nil : 3),
      status: :active, start_date: Date.current - 2.weeks, latitude: -33.96, longitude: 18.48
    }
    attrs.merge!(bucket_size: 25, buckets_per_collection: 2) if plan == "Commercial"
    Subscription.create!(attrs)
  end

  def collection_on(subscription, date)
    Collection.create!(subscription: subscription, date: date, bags: 0, buckets: 0.0, skip: false)
  end

  # A returning customer of the given plan (>1 past collection so not "new").
  def returning(plan: "Standard")
    sub = subscription_for(customer, plan: plan)
    2.times { |i| collection_on(sub, Date.current - (i + 1).weeks) }
    collection_on(sub, @date)
    sub
  end

  def get_links
    get driver_messages_path, params: { collection_day: "tuesday" }
  end

  test "the page renders without a day chosen" do
    get driver_messages_path
    assert_response :success
  end

  test "a returning standard customer gets the standard template with a real skip link" do
    sub = returning(plan: "Standard")
    upcoming = sub.collections.find_by(date: @date)

    get_links

    assert_response :success
    assert_match(/STD%20Thandi/, response.body, "standard template, {first_name} filled")
    assert_not_nil upcoming.reload.skip_token
    assert_match %r{skipme%2F#{upcoming.skip_token}}, response.body
  end

  test "a new customer gets the new-customer template and no skip link" do
    sub = subscription_for(customer)   # no past collections → new
    upcoming = collection_on(sub, @date)

    get_links

    assert_response :success
    assert_match(/NEW%20welcome%20Thandi/, response.body)
    assert_no_match %r{skipme%2F}, response.body
    assert_nil upcoming.reload.skip_token
  end

  test "a once-off customer gets the once-off template and no skip link" do
    sub = subscription_for(customer, plan: "once_off")
    collection_on(sub, @date)

    get_links

    assert_response :success
    assert_match(/ONCE%20Thandi/, response.body)
    assert_no_match %r{skipme%2F}, response.body
  end

  test "a commercial customer gets the commercial template and no skip link" do
    sub = returning(plan: "Commercial") # returning, but commercial still no skip
    upcoming = sub.collections.find_by(date: @date)

    get_links

    assert_response :success
    assert_match(/COMM%20Thandi/, response.body)
    assert_no_match %r{skipme%2F}, response.body
    assert_nil upcoming.reload.skip_token
  end

  test "each segment on the same day gets its own template" do
    returning(plan: "Standard")
    subscription_for(customer).tap { |s| collection_on(s, @date) }        # new
    subscription_for(customer, plan: "once_off").tap { |s| collection_on(s, @date) }

    get_links

    assert_response :success
    assert_match(/STD%20Thandi/, response.body)
    assert_match(/NEW%20welcome/, response.body)
    assert_match(/ONCE%20Thandi/, response.body)
  end

  test "falls back to the default template when none is saved" do
    DriverMessageTemplate.delete_all
    returning(plan: "Standard")

    get_links

    assert_response :success
    assert_match(/gooi%20day/i, response.body, "default standard template shows through")
  end
end
