require "test_helper"

class FillUpsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get fill_ups_new_url
    assert_response :success
  end

  test "should get index" do
    get fill_ups_index_url
    assert_response :success
  end
end
