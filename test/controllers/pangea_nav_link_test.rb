require "test_helper"

class PangeaNavLinkTest < ActionDispatch::IntegrationTest
  test "homepage links crew straight to the weight form during the festival weekend" do
    travel_to Date.new(2026, 10, 23) do
      get root_path
      assert_response :success
      assert_select "a[href=?]", new_festival_waste_log_path, text: "Pangea crew", minimum: 2
    end
  end

  test "link disappears after the weekend" do
    travel_to Date.new(2026, 10, 27) do
      get root_path
      assert_select "a[href=?]", new_festival_waste_log_path, count: 0
    end
  end

  test "unauthenticated crew land on login, which returns them to the form" do
    get new_festival_waste_log_path
    assert_redirected_to new_festival_session_path
  end
end
