require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "pay@example.com",
      password: "password",
      customer_id: "GFWC999",
      phone_number: "+27836353126",
      referral_code: "MYCODE"
    )
    puts "Creating Alfred"
    alfred = User.find_or_create_by!(email: "driver@gooi.com") do |user|
      user.first_name = "Alfred"
      user.last_name = "Mbonjwa"
      user.password = "password"
      user.role = "driver"
      user.phone_number = "+27785325513"
    end
    puts "Alfred created with user id: #{alfred.id}"


    @referrer = User.create!(
      email: "ref@example.com",
      password: "password",
      customer_id: "GFWC998",
      phone_number: "+27836353126",
      referral_code: "REF123"
    )

    @subscription = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 1,
      street_address: "123 Main",
      suburb: "Cape Town",
      referral_code: @referrer.referral_code,
      customer_id: "GFWC999"
    )

    @invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Date.today,
      due_date: Date.today + 14,
      total_amount: 660,
      paid: false
    )

    @compost_bags = Product.create!(
      title: "Compost bin bags",
      description: "Extra bin bags for your compost",
      price: 30
    )

    @soil_bags = Product.create!(
      title: "Soil for Life Compost",
      description: "Organic compost for gardening",
      price: 50
    )

    # Optional: create a referral
    @referral = Referral.create!(
      referrer: @referrer,
      referee: @user,
      subscription: @subscription,
      status: :pending
    )

    @old_subscription = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 1,
      start_date: 2.months.ago.to_date,
      end_date: 1.month.ago.to_date,
      status: :completed
    )

    4.times do |i|
      Collection.create!(
        subscription: @old_subscription,
        date: @old_subscription.end_date + (i + 1).weeks
      )
    end
    @payload = {
      "id" => 999,
      "status" => "completed",
      "totalAmount" => 66000,
      "tipAmount" => 0,
      "feeAmount" => 1500,
      "settleAmount" => 64500,
      "date" => Time.now.iso8601,
      "userReference" => "Test User",
      "merchantReference" => @user.customer_id,
      "extra" => {
        "invoiceId" => @invoice.id
      }
    }

    @auth_key = "test_key"
    ENV["WEBHOOK_AUTH_KEY"] = @auth_key

    @params = {
      "payload" => @payload.to_json
    }
    body_string = "payload=#{@params["payload"]}"
    @signature = OpenSSL::HMAC.hexdigest("sha256", @auth_key, body_string)

    @headers = {
      "Authorization" => "SnapScan signature=#{@signature}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }
  end

  test "creates payment and updates everything correctly" do
    raw_body = "payload=#{CGI.escape(@payload.to_json)}"
    signature = OpenSSL::HMAC.hexdigest("sha256", @auth_key, raw_body)

    headers = {
      "Authorization" => "SnapScan signature=#{signature}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }

    post "/snapscan/webhook", headers: headers, params: raw_body, as: :raw
    assert_response :success


    payment = Payment.last
    puts "Here in the test file should be the payemnt: #{payment.user.customer_id}"

    assert_equal @user.id, payment.user_id
    puts "#{payment.user_id}"
    assert_equal "completed", payment.status
    assert_equal @invoice.id, payment.invoice_id
    assert @invoice.reload.paid

    assert @subscription.reload.active?, "Subscription should be active"
    assert_not_nil @subscription.start_date, "Subscription should have a start date"

    collection = Collection.last
    assert_equal @subscription, collection.subscription

    assert_equal "completed", @referral.reload.status
  end

  test "resubscription payment sets start_date after last subscription if collections continued" do
    raw_body = "payload=#{CGI.escape(@payload.to_json)}"
    signature = OpenSSL::HMAC.hexdigest("sha256", @auth_key, raw_body)

    headers = {
      "Authorization" => "SnapScan signature=#{signature}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }

    post "/snapscan/webhook", headers: headers, params: raw_body, as: :raw

    puts "❗️Response code: #{response.status}"
    puts "❗️Response body: #{response.body}"

    assert_response :success

    @subscription.reload
    expected_start = @old_subscription.end_date + 1.day
    assert_equal expected_start.to_date, @subscription.start_date.to_date, "Start date should continue from old sub if collections match"

    payment = Payment.last
    assert_equal @user.id, payment.user_id
    assert_equal "completed", payment.status
    assert_equal @invoice.id, payment.invoice_id
    assert @invoice.reload.paid
    assert @subscription.active?

    collection = Collection.last
    assert_equal @subscription, collection.subscription
    assert_equal "completed", @referral.reload.status
  end


end
