require "test_helper"

class FestivalWasteLogsEditTest < ActionDispatch::IntegrationTest
  setup do
    @event = FestivalEvent.create!(name: "Pangea", start_date: Date.today, end_date: Date.today + 2)
    @other = FestivalEvent.create!(name: "Other", start_date: Date.today, end_date: Date.today + 2)
    @crew  = @event.festival_participants.create!(name: "Sam", pin: "1234")
    @log = @event.festival_waste_logs.create!(day_number: 1, logged_at: Time.current, category: "organic",
                                              gross_kg: 20, container_size: 45, source: "vendor", destination: "pigs")
    post festival_sessions_path, params: { festival_event_id: @event.id, name: "Sam", pin: "1234" }
  end

  test "crew can edit an organic entry and the tare is recomputed" do
    patch festival_waste_log_path(@log), params: { day_number: 2, logged_at: Time.current, gross_kg: 30,
                                                   container_size: 25, source: "attendee", destination: "compost" }
    assert_redirected_to festival_waste_logs_path
    @log.reload
    assert_equal 2, @log.day_number
    assert_in_delta 30 - Bucket::TARE_25L_KG, @log.weight_kg.to_f, 0.0001
    assert_equal "attendee", @log.source
  end

  test "bogus enum values are ignored rather than raising" do
    patch festival_waste_log_path(@log), params: { day_number: 1, logged_at: Time.current, gross_kg: 20,
                                                   container_size: 45, source: "nope", destination: "pigs" }
    assert_redirected_to festival_waste_logs_path
    assert_nil @log.reload.source
  end

  test "invalid weight re-renders the form" do
    patch festival_waste_log_path(@log), params: { day_number: 1, logged_at: Time.current, gross_kg: 1,
                                                   container_size: 45 }
    assert_response :unprocessable_entity
  end

  test "crew cannot touch another festival's entries" do
    foreign = @other.festival_waste_logs.create!(day_number: 1, logged_at: Time.current, category: "glass", weight_kg: 2)
    get edit_festival_waste_log_path(foreign)
    assert_response :not_found
  end

  test "crew can delete an entry" do
    assert_difference -> { FestivalWasteLog.count }, -1 do
      delete festival_waste_log_path(@log)
    end
  end

  test "edit page renders" do
    get edit_festival_waste_log_path(@log)
    assert_response :success
  end
end
