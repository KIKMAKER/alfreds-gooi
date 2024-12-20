# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:snapscan_webhook, :fetch_snapscan_payments]
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!


  def index
    @payments = Payment.all.order(created_at: :desc)
  end

  def show
    @payment = Payment.find(params[:id])
  end

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
      # Find the invoice by the invoice_id
      invoice = Invoice.find_by(id: payload["extra"]["invoice_id"])

      if payload["status"] == "completed"
        handle_payment_payload(payload, user, invoice)
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

  def handle_payment_payload(payment_data, user, invoice)
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
    invoice.update(paid: true)
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
    received_signature = request.headers['Authorization'].to_s.split('=').last
    computed_signature = OpenSSL::HMAC.hexdigest('sha256', webhook_auth_key, request_body)

    Rails.logger.debug "Expected: #{computed_signature}, Received: #{received_signature}"

    unless Rack::Utils.secure_compare(computed_signature, received_signature)
      raise "Unauthorized webhook received"
    end
  end
end
