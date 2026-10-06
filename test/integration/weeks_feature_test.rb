require "test_helper"

class WeeksFeatureTest < ActionDispatch::IntegrationTest
  setup do
    @alfred = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", og: false,
      role: :driver
    )
    sign_in @alfred
  end

  test "weeks index renders and resend delivers mail" do
    thursday = Date.current.beginning_of_week(:monday) + 3.days
    dd = DriversDay.create!(date: thursday, user: @alfred)
    dd.buckets.create!(bucket_size: 25, weight_kg: 5.0)

    get weeks_drivers_days_path
    assert_response :success
    assert_match "Weekly Stats", response.body

    assert_emails 1 do
      post resend_weekly_stats_drivers_day_path(dd)
    end
    assert_redirected_to weeks_drivers_days_path
    dd.reload
    assert dd.weekly_stats_sent_at.present?
  end
end
