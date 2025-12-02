require "test_helper"

class Admin::BulkMessagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_bulk_messages_index_url
    assert_response :success
  end
end
