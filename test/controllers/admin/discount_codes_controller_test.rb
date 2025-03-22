require "test_helper"

class Admin::DiscountCodesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_discount_codes_index_url
    assert_response :success
  end

  test "should get new" do
    get admin_discount_codes_new_url
    assert_response :success
  end

  test "should get create" do
    get admin_discount_codes_create_url
    assert_response :success
  end

  test "should get show" do
    get admin_discount_codes_show_url
    assert_response :success
  end
end
