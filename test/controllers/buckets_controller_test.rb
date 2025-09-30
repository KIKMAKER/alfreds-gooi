require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get buckets_index_url
    assert_response :success
  end
end
