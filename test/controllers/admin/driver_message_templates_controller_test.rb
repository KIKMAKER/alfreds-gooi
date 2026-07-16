# frozen_string_literal: true
require "test_helper"

class Admin::DriverMessageTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Kiki", last_name: "Kennedy",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "admin-#{SecureRandom.hex(3)}@gmail.com", og: false, role: :admin
    )
    @customer = User.create!(
      first_name: "Thandi", last_name: "Mokoena",
      phone_number: "+2782111#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", og: false
    )
  end

  test "the edit page renders the four segment fields for an admin" do
    sign_in @admin
    get edit_admin_driver_message_templates_path

    assert_response :success
    assert_select "textarea[name='driver_message_templates[standard]']"
    assert_select "textarea[name='driver_message_templates[commercial]']"
  end

  test "a non-admin cannot open the edit page" do
    sign_in @customer
    get edit_admin_driver_message_templates_path
    assert_redirected_to root_path
  end

  test "an admin can save all segment templates at once" do
    sign_in @admin
    patch admin_driver_message_templates_path, params: {
      driver_message_templates: {
        "standard" => "New standard body {skip_link}",
        "new_customer" => "New newbie body",
        "once_off" => "New once-off body",
        "commercial" => "New commercial body"
      }
    }

    assert_redirected_to edit_admin_driver_message_templates_path
    assert_equal "New standard body {skip_link}", DriverMessageTemplate.body_for("standard")
    assert_equal "New commercial body", DriverMessageTemplate.body_for("commercial")
  end

  test "saving updates an existing row rather than duplicating" do
    sign_in @admin
    DriverMessageTemplate.create!(segment: "once_off", body: "old")

    assert_no_difference -> { DriverMessageTemplate.where(segment: "once_off").count } do
      patch admin_driver_message_templates_path, params: {
        driver_message_templates: { "once_off" => "new" }
      }
    end
    assert_equal "new", DriverMessageTemplate.body_for("once_off")
  end

  test "a non-admin is turned away and nothing is saved" do
    sign_in @customer
    patch admin_driver_message_templates_path, params: {
      driver_message_templates: { "standard" => "hacked" }
    }

    assert_redirected_to root_path
    assert_nil DriverMessageTemplate.find_by(segment: "standard")
  end
end
