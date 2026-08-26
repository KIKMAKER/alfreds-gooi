# frozen_string_literal: true
require "test_helper"
require "ostruct"

class SubscriptionsControllerTest < ActionController::TestCase
  tests SubscriptionsController

  # Simple fake that matches InvoiceBuilder's API.
  # #call returns a double (not a plain OpenStruct) because invoice_path(@invoice)
  # needs #to_param to build a real URL — OpenStruct doesn't define one and Minitest's
  # #stub calls any #call-able value it's given rather than returning it verbatim, so
  # .new must itself return something with #call.
  class FakeInvoiceBuilder
    FakeInvoice = Struct.new(:id) do
      def to_param = id.to_s
    end

    def initialize(*) = nil
    def call(**) = FakeInvoice.new(123)
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
      suburb: suburb_fixture("Rondebosch", collection_day: "Tuesday"),
      collection_day: "Tuesday",
      collection_order: 42,
      duration: 1,
      status: :completed,
      plan: "Standard",
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
        street_address: "ignored by controller (copied from last)"
      },
      og: "false",
      new: "true"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      InvoiceBuilder.stub :new, ->(**) { FakeInvoiceBuilder.new } do
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

    assert_redirected_to invoice_path(123)
  end

  test "create uses early-renewal behavior (day after prev end, aligned to weekday)" do
    params = {
      subscription: { plan: "Standard", duration: 1, street_address: "x" },
      og: "false", new: "true"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      InvoiceBuilder.stub :new, ->(**) { FakeInvoiceBuilder.new } do
        post :create, params: params
      end
    end

    created = @user.subscriptions.order(created_at: :desc).first

    expected_base = @prev.end_date.to_date + 1.day
    ruby_wday     = created.send(:normalize_to_ruby_wday, created.collection_day)
    aligned       = created.send(:align_to_wday, expected_base, ruby_wday) # => Date

    assert_equal aligned, created.start_date.to_date
  end

  test "create raises error when previous subscription has no suburb" do
    params = {
      subscription: { plan: "Standard", duration: 1 },
      og: "false",
      new: "false"
    }

    # Force the new sub to fail validation by making the copied suburb blank
    @prev.update_column(:suburb_id, nil)

    @user.stub :referrals_as_referrer, @ref_stub do
      post :create, params: params
    end

    assert_response :unprocessable_entity
    assert_match(/went wrong/i, flash[:alert])
  end

  test "OG user renewing 6-month subscription creates invoice with correct OG product (R720)" do
    # Make user OG
    @user.update!(og: true)

    # Ensure the product exists
    og_product = Product.find_or_create_by!(title: "Standard 6 month OG subscription") do |p|
      p.price = 720.0
      p.description = "6 month OG subscription"
    end

    params = {
      subscription: { plan: "Standard", duration: 6 },
      og: "true",
      new: "false"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      post :create, params: params
    end

    created = @user.subscriptions.order(created_at: :desc).first
    assert_equal 6, created.duration, "Subscription duration should be 6 months"
    assert_equal "Standard", created.plan, "Subscription plan should be Standard"

    # Check invoice was created with correct product
    invoice = created.invoices.order(created_at: :asc).last
    assert_not_nil invoice, "Invoice should be created"

    invoice_item = invoice.invoice_items.find_by(product: og_product)
    assert_not_nil invoice_item, "Invoice should have Standard 6 month OG subscription product"
    assert_equal 720.0, invoice_item.amount, "Invoice item amount should be R720"
    assert_equal 1, invoice_item.quantity, "Invoice item quantity should be 1"

    assert_redirected_to invoice_path(invoice)
  end

  test "non-OG user renewing 3-month subscription creates invoice with correct standard product" do
    # Ensure user is not OG
    @user.update!(og: false)

    # Ensure the product exists
    standard_product = Product.find_or_create_by!(title: "Standard 3 month subscription") do |p|
      p.price = 660.0
      p.description = "3 month subscription"
    end

    params = {
      subscription: { plan: "Standard", duration: 3 },
      og: "false",
      new: "false"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      post :create, params: params
    end

    created = @user.subscriptions.order(created_at: :desc).first
    assert_equal 3, created.duration, "Subscription duration should be 3 months"
    assert_equal "Standard", created.plan, "Subscription plan should be Standard"

    # Check invoice was created with correct product
    invoice = created.invoices.order(created_at: :asc).last
    assert_not_nil invoice, "Invoice should be created"

    invoice_item = invoice.invoice_items.find_by(product: standard_product)
    assert_not_nil invoice_item, "Invoice should have Standard 3 month subscription product"
    assert_equal 660.0, invoice_item.amount, "Invoice item amount should be R660"
    assert_equal 1, invoice_item.quantity, "Invoice item quantity should be 1"

    assert_redirected_to invoice_path(invoice)
  end

  test "renewal with discount code creates subscription with discount_code" do
    # Ensure user is not OG
    @user.update!(og: false)

    # Ensure the product exists
    Product.find_or_create_by!(title: "Standard 6 month subscription") do |p|
      p.price = 1080.0
      p.description = "6 month subscription"
    end

    params = {
      subscription: { plan: "Standard", duration: 6, discount_code: "SUMMER2025" },
      og: "false",
      new: "false"
    }

    @user.stub :referrals_as_referrer, @ref_stub do
      post :create, params: params
    end

    created = @user.subscriptions.order(created_at: :desc).first
    assert_equal "SUMMER2025", created.discount_code, "Subscription should have discount code saved"
    assert_equal 6, created.duration, "Subscription duration should be 6 months"

    invoice = created.invoices.order(created_at: :asc).last
    assert_not_nil invoice, "Invoice should be created"
    assert_redirected_to invoice_path(invoice)
  end

  test "holiday_dates on primary propagates holiday and skipped collections to satellite" do
    primary = Subscription.create!(
      user: @user, street_address: "1 Primary Rd",
      suburb: suburb_fixture("Rondebosch", collection_day: "Tuesday"),
      collection_day: "Tuesday", duration: 1, status: :active, plan: "Commercial", buckets_per_collection: 2,
      start_date: Date.current, latitude: -33.96, longitude: 18.48,
      customer_id: @user.customer_id
    )
    satellite = Subscription.create!(
      user: @user, street_address: "1 Primary Rd",
      suburb: suburb_fixture("Gardens", collection_day: "Thursday"),
      collection_day: "Thursday", duration: 1, status: :active, plan: "Commercial", buckets_per_collection: 2,
      start_date: Date.current, latitude: -33.93, longitude: 18.41,
      customer_id: @user.customer_id, primary_subscription: primary
    )

    primary_collection = Collection.create!(subscription: primary, date: Date.current + 5.days)
    satellite_collection = Collection.create!(subscription: satellite, date: Date.current + 6.days)

    post :holiday_dates, params: {
      id: primary.id,
      subscription: { holiday_start: Date.current + 3.days, holiday_end: Date.current + 10.days }
    }

    satellite.reload
    assert_equal primary.reload.holiday_start.to_date, satellite.holiday_start.to_date
    assert_equal primary.holiday_end.to_date, satellite.holiday_end.to_date

    assert primary_collection.reload.skip
    assert_equal "holiday", primary_collection.skip_reason
    assert satellite_collection.reload.skip
    assert_equal "holiday", satellite_collection.skip_reason
  end

  test "clear_holiday on satellite propagates back to primary" do
    primary = Subscription.create!(
      user: @user, street_address: "1 Primary Rd",
      suburb: suburb_fixture("Rondebosch", collection_day: "Tuesday"),
      collection_day: "Tuesday", duration: 1, status: :active, plan: "Commercial", buckets_per_collection: 2,
      start_date: Date.current, latitude: -33.96, longitude: 18.48,
      customer_id: @user.customer_id,
      holiday_start: Date.current + 1.day, holiday_end: Date.current + 5.days
    )
    satellite = Subscription.create!(
      user: @user, street_address: "1 Primary Rd",
      suburb: suburb_fixture("Gardens", collection_day: "Thursday"),
      collection_day: "Thursday", duration: 1, status: :active, plan: "Commercial", buckets_per_collection: 2,
      start_date: Date.current, latitude: -33.93, longitude: 18.41,
      customer_id: @user.customer_id, primary_subscription: primary,
      holiday_start: Date.current + 1.day, holiday_end: Date.current + 5.days
    )

    primary_collection = Collection.create!(subscription: primary, date: Date.current + 2.days, skip: true, skip_reason: "holiday")
    satellite_collection = Collection.create!(subscription: satellite, date: Date.current + 2.days, skip: true, skip_reason: "holiday")

    post :clear_holiday, params: { id: satellite.id }

    assert_nil primary.reload.holiday_start
    assert_nil satellite.reload.holiday_start

    assert_not primary_collection.reload.skip
    assert_nil primary_collection.skip_reason
    assert_not satellite_collection.reload.skip
    assert_nil satellite_collection.skip_reason
  end
end
