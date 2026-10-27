require "test_helper"

class Admin::FestivalWasteLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Kiki", last_name: "Kennedy",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "admin-#{SecureRandom.hex(3)}@gmail.com", role: :admin
    )
    @wrong = FestivalEvent.create!(name: "Wrong fest", start_date: Date.today, end_date: Date.today + 2)
    @right = FestivalEvent.create!(name: "Right fest", start_date: Date.today, end_date: Date.today + 2)
    @crew  = @wrong.festival_participants.create!(name: "Sam", pin: "1234")
    @log = @wrong.festival_waste_logs.create!(day_number: 1, logged_at: Time.current, category: "glass",
                                              weight_kg: 4, festival_participant: @crew)
    sign_in @admin
  end

  test "edit page offers every festival and links back to the index" do
    get edit_admin_festival_event_festival_waste_log_path(@wrong, @log)
    assert_response :success
    assert_select "select#festival_event_id_new option", 2
    assert_select "a[href=?]", admin_festival_events_path
  end

  test "an entry can be moved to another festival" do
    patch admin_festival_event_festival_waste_log_path(@wrong, @log),
          params: { festival_event_id_new: @right.id, day_number: 1, logged_at: Time.current, weight_kg: 4 }
    assert_redirected_to dashboard_admin_festival_event_path(@right)
    @log.reload
    assert_equal @right, @log.festival_event
    assert_nil @log.festival_participant
  end

  test "entries from another festival are not reachable under this festival" do
    other = @right.festival_waste_logs.create!(day_number: 1, logged_at: Time.current, category: "tin", weight_kg: 1)
    get edit_admin_festival_event_festival_waste_log_path(@wrong, other)
    assert_response :not_found
  end

  test "admin can delete an entry" do
    assert_difference -> { FestivalWasteLog.count }, -1 do
      delete admin_festival_event_festival_waste_log_path(@wrong, @log)
    end
  end
end
