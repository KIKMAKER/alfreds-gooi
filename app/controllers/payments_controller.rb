class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:snapscan_webhook, :fetch_snapscan_payments]
  skip_before_action :verify_authenticity_token

  def snapscan_webhook
    request_body = request.body.read
    verify_signature(request_body, ENV['SNAPSCAN_API_KEY'])
    payload = JSON.parse(request_body)
    puts ">>> Received payload: #{payload.inspect}"

    handle_payment_payload(payload["payload"])

    render json: { status: 'success' }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity

    # i'd like to handle payload logic here, i.e inspect the payload and update the subscription

  end
  def fetch_snapscan_payments
    api_key = ENV['SNAPSCAN_API_KEY']
    service = SnapscanService.new(api_key)
    payments = service.fetch_payments

    if payments
      # Process payments
      puts "Payments: #{payments.inspect}"
      render json: payments, status: :ok
    else
      render json: { error: 'Failed to fetch payments' }, status: :unprocessable_entity
    end
  end
  private

  def handle_payment_payload(payment_data)
    Payment.create!(
      snapscan_id: payment_data["id"],
      status: payment_data["status"],
      total_amount: payment_data["totalAmount"],
      tip_amount: payment_data["tipAmount"],
      fee_amount: payment_data["feeAmount"],
      settle_amount: payment_data["settleAmount"],
      date: payment_data["date"],
      user_reference: payment_data["userReference"],
      merchant_reference: payment_data["merchantReference"]
      user_id: current_user.id
    )

    update_subscription_status(payment_data["merchantReference"])
  end

  def update_subscription_status(merchant_reference)
    subscription = Subscription.find_by(customer_id: merchant_reference)
    if subscription
      subscription.update(start_date: subscription.calculate_next_collection_day)
      puts "Subscription #{subscription.id} for customer #{merchant_reference} updated to active."
    else
      puts "No subscription found for customer #{merchant_reference}."
    end
  end

  def verify_signature(request_body, webhook_auth_key)
    signature = OpenSSL::HMAC.hexdigest('sha256', webhook_auth_key, request_body)
    auth_signature = "SnapScan signature=#{signature}"

    unless Rack::Utils.secure_compare(auth_signature, request.headers['Authorization'])
      raise "Unauthorized webhook received"
    end
  end

end
