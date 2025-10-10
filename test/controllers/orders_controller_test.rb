require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "should get add_item" do
    get orders_add_item_url
    assert_response :success
  end

  test "should get remove_item" do
    get orders_remove_item_url
    assert_response :success
  end

  test "should get checkout" do
    get orders_checkout_url
    assert_response :success
  end
end
