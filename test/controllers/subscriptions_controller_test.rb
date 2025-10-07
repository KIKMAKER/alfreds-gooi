# frozen_string_literal: true
require "test_helper"
require "ostruct"

class SubscriptionsControllerTest < ActionController::TestCase
  tests SubscriptionsController

  # Simple fake that matches InvoiceBuilder's API
  class FakeInvoiceBuilder
    def initialize(*) = nil
    def call(**) = OpenStruct.new(id: 123)
  end

  setup do
    # basic user
    @user = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+27836353126", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@example.com", og: false
    )
    @user.update!(customer_id: @user.customer_id || "GFWC#{rand(1000..9999)}")

    # previous sub we copy attributes from
    @prev = Subscription.create!(
      user: @user,
      street_address: "123 Demo St, Rondebosch",
      suburb: "Rondebosch",
      collection_day: "Tuesday",
      collection_order: 42,
      duration: 1,
      status: :completed,
      start_date: Date.current - 3.weeks,
      end_date:   Date.current + 1.week,  # early renewal case
      latitude: -33.96, longitude: 18.48,
      customer_id: @user.customer_id
    )

    # referrals chain → count = 0
    @ref_stub = Object.new
    def @ref_stub.where(*); self; end
    def @ref_stub.count; 0; end

    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in @user
  end

  test "create persists sub, copies attrs, sets start_date via suggested_start_date, builds invoice, redirects" do
    params = {
      subscription: {
        plan: "Standard",
        duration: 1,
        street_address: "ignored by controller (copied from last)",
        suburb: "Rondebosch"
      },
      og: "false",
      new: "true"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      InvoiceBuilder.stub :new, FakeInvoiceBuilder.new do
        post :create, params: params
      end
    end

    created = @user.subscriptions.order(created_at: :desc).first
    assert created.persisted?, "new subscription should be saved"
    assert_equal @prev.customer_id,     created.customer_id
    assert_equal @prev.suburb,          created.suburb
    assert_equal @prev.street_address,  created.street_address
    assert_equal @prev.collection_order, created.collection_order
    assert_equal false, created.is_new_customer
    assert_not_nil created.start_date,  "start_date should be persisted"

    assert_redirected_to want_bags_subscription_path(created)
  end

  test "create uses early-renewal behavior (day after prev end, aligned to weekday)" do
    params = {
      subscription: { plan: "Standard", duration: 1, street_address: "x", suburb: "Rondebosch" },
      og: "false", new: "true"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      InvoiceBuilder.stub :new, FakeInvoiceBuilder.new do
        post :create, params: params
      end
    end

    created = @user.subscriptions.order(created_at: :desc).first

    expected_base = @prev.end_date.to_date + 1.day
    ruby_wday     = created.send(:normalize_to_ruby_wday, created.collection_day)
    aligned       = created.send(:align_to_wday, expected_base, ruby_wday) # => Date

    assert_equal aligned, created.start_date.to_date
  end

  test "create renders :new with 422 when save fails" do
    params = {
      subscription: { plan: "Standard", duration: 1, street_address: "x", suburb: "Rondebosch" },
      og: "false", new: "true"
    }

    # Force the new sub to fail validation by making the copied suburb invalid
    @prev.update_column(:suburb, "InvalidSuburb")

    @user.stub :referrals_as_referrer, @ref_stub do
      InvoiceBuilder.stub :new, FakeInvoiceBuilder.new do
        post :create, params: params
      end
    end

    assert_response :unprocessable_entity
  end
end
