require "test_helper"

class Admin::DiscountCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "admin@example.com", password: "password", role: 'admin', phone_number: '0836353126')
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: "password",
        phone_number: '0836353126'
      }
    }
    follow_redirect!
    # sign_in @admin

    @code = DiscountCode.create!(
      code: "EARTHWEEK",
      discount_cents: 6600,
      usage_limit: 10,
      used_count: 0,
      expires_at: 1.month.from_now
    )
  end

  test "should get index" do
    get admin_discount_codes_path
    assert_response :success
    assert_select "h1", "All Discount Codes"
  end

  test "should get new" do
    get new_admin_discount_code_path
    assert_response :success
    assert_select "form"
  end

  test "should create discount code" do
    assert_difference("DiscountCode.count") do
      post admin_discount_codes_path, params: {
        discount_code: {
          code: "GOOIFEST2025",
          discount_cents: 4400,
          usage_limit: 5,
          expires_at: 1.week.from_now
        }
      }
    end

    assert_redirected_to admin_discount_code_path(DiscountCode.last)
    follow_redirect!
    assert_match "GOOIFEST2025", response.body
  end

  test "should show discount code" do
    get admin_discount_code_path(@code)
    assert_response :success
    assert_select "h2", text: /EARTHWEEK/
  end
end
