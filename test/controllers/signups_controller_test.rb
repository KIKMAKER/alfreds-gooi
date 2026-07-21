require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  def start_signup(extra_params: {})
    get new_account_signup_path({ plan: "Standard", duration: "6" }.merge(extra_params))

    post create_account_signup_path, params: {
      user: {
        first_name: "Launch", last_name: "Customer",
        email: "signup_test_#{SecureRandom.hex(4)}@example.com",
        phone_number: "+2783#{rand(1_000_000..9_999_999)}",
        password: "password", password_confirmation: "password"
      }
    }
  end

  test "a normal signup does not set og and lets the suburb be picked" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    start_signup

    get new_subscription_details_path
    assert_select "select#subscription_suburb_id"

    post create_subscription_path, params: {
      subscription: { street_address: "1 Main Road", suburb_id: suburb.id }
    }

    user = User.order(:created_at).last
    assert_not user.og?
    assert_equal suburb, user.subscriptions.first.suburb
  end

  test "a signup started from a suburb launch page locks the suburb and sets og" do
    launch_suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    other_suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")

    start_signup(extra_params: { suburb_id: launch_suburb.id, og: "true" })

    get new_subscription_details_path
    assert_select "select#subscription_suburb_id", count: 0
    assert_select "input[type=hidden][name='subscription[suburb_id]'][value=?]", launch_suburb.id.to_s

    # Even if a tampered/duplicate suburb_id were posted, the session-locked value wins.
    post create_subscription_path, params: {
      subscription: { street_address: "1 Main Road", suburb_id: other_suburb.id }
    }

    user = User.order(:created_at).last
    assert user.og?
    assert_equal launch_suburb, user.subscriptions.first.suburb
  end
end
