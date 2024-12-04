# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:snapscan_webhook, :fetch_snapscan_payments]
  skip_before_action :verify_authenticity_token

  def snapscan_webhook
    begin
      request_body = request.body.read
      Rails.logger.debug "Request Body: #{request_body}"

      # Verify signature
      verify_signature(request_body, ENV['WEBHOOK_AUTH_KEY'])

      # Parse payload from URL-encoded parameters
      parsed_params = Rack::Utils.parse_nested_query(request_body)
      payload = JSON.parse(parsed_params["payload"])
      Rails.logger.debug "Received payload: #{payload.inspect}"

      # Find the user by customer_id
      user = User.find_by(customer_id: payload["merchantReference"])

      if payload["status"] == "completed"
        handle_payment_payload(payload, user)
        render json: { status: 'success' }, status: :ok
      else
        render json: { status: 'error', message: 'Payment not successful' }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error processing SnapScan webhook: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end


  def fetch_snapscan_payments
    # Refactor to model
    api_key = ENV['WEBHOOK_AUTH_KEY']
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

  def handle_payment_payload(payment_data, user)
    Payment.create!(
      snapscan_id: payment_data["id"],
      status: payment_data["status"],
      total_amount: payment_data["totalAmount"],
      tip_amount: payment_data["tipAmount"],
      fee_amount: payment_data["feeAmount"],
      settle_amount: payment_data["settleAmount"],
      date: payment_data["date"],
      user_reference: payment_data["userReference"],
      merchant_reference: payment_data["merchantReference"],
      user_id: user.id
    )

    update_subscription_status(payment_data["merchantReference"])
  end

  def update_subscription_status(merchant_reference)
    subscription = Subscription.find_by(customer_id: merchant_reference)
    if subscription
      subscription.update(
        status: 'active',
        start_date: subscription.calculate_next_collection_day
      )
      puts "Subscription #{subscription.id} for customer #{merchant_reference} updated to active with start date #{subscription.start_date}."
    else
      puts "No subscription found for customer #{merchant_reference}."
    end
  end

  def verify_signature(request_body, webhook_auth_key)
    signature = OpenSSL::HMAC.hexdigest('sha256', webhook_auth_key, request_body)
    auth_signature = "SnapScan signature=#{signature}"

    Rails.logger.debug "Expected: #{auth_signature}, Received: #{request.headers['Authorization']}"

    unless Rack::Utils.secure_compare(auth_signature, request.headers['Authorization'])
      raise "Unauthorized webhook received"
    end
  end
end
