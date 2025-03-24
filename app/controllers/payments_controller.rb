# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:snapscan_webhook, :fetch_snapscan_payments]
  skip_before_action :authenticate_user!, only: [:snapscan_webhook, :fetch_snapscan_payments]

  def index
    @payments = Payment.all.order(date: :desc)
  end

  def show
    @payment = Payment.find(params[:id])
  end

  def snapscan_webhook
    Rails.logger.info "INFO: WE HIT THE SNAPSCAN WEBHOOK."
    # Rails.logger.debug "DEBUG: Testing detailed logging in production."
    # Rails.logger.error "ERROR: Testing error logging in production."

    begin
      request_body = request.body.read
      request.body.rewind
      Rails.logger.debug "Request Body: #{request_body}"

      # Rails.logger.debug "Request Body: #{request_body}"
      Rails.logger.debug "Received SnapScan Webhook: #{params.inspect}"

      # Verify signature
      verify_signature(request_body, ENV['WEBHOOK_AUTH_KEY'])

      # Parse payload from URL-encoded parameters
      payload = JSON.parse(params[:payload])

      Rails.logger.debug "Received payload: #{payload.inspect}"
      customer_id = payload["merchantReference"]

      if customer_id.blank?
        Rails.logger.error "⚠️ Missing merchantReference - can't find user!"
        return render json: { error: "Missing merchantReference" }, status: :unprocessable_entity
      end
      # Find the user by customer_id
      user = User.find_by(customer_id: customer_id)

      # check if there is a user (payment may come from the app without any references)
      if user.nil?
        Rails.logger.error "⚠️ No user found with customer_id: #{customer_id}"
        return render json: { error: "User not found" }, status: :not_found
      end

      invoice_id = payload.dig("extra", "invoiceId")&.to_i
      invoice = Invoice.find_by(id: invoice_id) if invoice_id.present?

      if invoice.nil?
        Rails.logger.error "Invoice not found with id: #{payload['extra']['invoiceId']}"
        puts "Invoice not found with id: #{payload['extra']['invoiceId']}"
        return render json: { error: "Invoice not found" }, status: :not_found
      end

      case payload["status"]
      when "completed"
        payment = handle_payment_payload(payload, user, invoice)
        payment.user = user
        payment.save!
        puts "Here should be the first payemnt: #{payment.user.customer_id}"
        if invoice.present?
          subscription = invoice.subscription

          invoice.update!(paid: true)

          puts "Payment: user_id #{payment.user_id}, invoice_id: #{payment.invoice_id}"
          compost_bags = Product.find_by(title: "Compost bin bags")
          invoice_compost_bags = invoice.invoice_items.find_by(product_id: compost_bags.id)
          soil_bags = Product.find_by(title: "Soil for Life Compost")
          invoice_soil_bags = invoice.invoice_items.find_by(product_id: soil_bags.id)

          first_collection = CreateFirstCollectionJob.perform_now(subscription)
          if invoice_compost_bags
            first_collection.update!(needs_bags: invoice_compost_bags.quantity)
          end
          if invoice_soil_bags
            first_collection.update!(soil_bag: invoice_soil_bags.quantity)
          end
          render json: { status: 'success' }, status: :ok and return
        else
          # No invoice found - this is a manual SnapScan payment, probably directly into your account
          Rails.logger.warn "⚠️ Manual SnapScan payment detected! User: #{user.customer_id}, Amount: #{payload['totalAmount']}, SnapScan ID: #{payload['id']}. Follow up manually."
        end
      when "error"
        Rails.logger.error "Payment failed for user #{user&.id}, invoice #{invoice&.id || 'N/A'}. SnapScan ID: #{payload['id']}"
        render json: { status: 'failed', message: 'Payment was not successful' }, status: :ok and return # ✅ Use 200 OK instead of 422
      else
        Rails.logger.warn "Unhandled payment status: #{payload['status']}"
        render json: { status: 'ignored', message: 'Unhandled payment status' }, status: :ok and return
      end

    rescue => e
      Rails.logger.error "💥 Error processing SnapScan webhook: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end


  def fetch_snapscan_payments
    # Refactor to model
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

  def handle_payment_payload(payment_data, user, invoice)
    payment = Payment.create!(
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
    subscription = invoice.subscription
    return payment unless subscription
    payment.invoice = invoice
    payment.save!
    invoice.update!(paid: true)
    update_subscription_status(subscription)
    update_referral(subscription)
    CreateFirstCollectionJob.perform_now(subscription)

    return payment
  end

  def update_subscription_status(subscription)
    if subscription
      subscription.update!(
        status: 'active',
        start_date: subscription.suggested_start_date(payment_date: Time.zone.today)
      )
      puts "Subscription #{subscription.id} for customer #{subscription.customer_id} updated to active with start date #{subscription.start_date}."
    else
      puts "No subscription found for customer this customer."
    end
  end

  def update_referral(subscription)
    return unless subscription # just in case
    referral_code = subscription.referral_code
    return unless referral_code # nothing to do

    referrer = User.find_by(referral_code: referral_code)
    return unless referrer # invalid referral code

    referee = subscription.user
    referral = Referral.find_by(referee_id: referee.id, referrer_id: referrer.id)

    referral&.completed!
  end

  def verify_signature(request_body, webhook_auth_key)
    return true if Rails.env.test?
    # Extract the Authorization header and received signature
    received_auth_header = request.headers['Authorization'].to_s
    received_signature = received_auth_header.split('=').last

    Rails.logger.debug "Received Signature: #{received_signature.inspect}"
    Rails.logger.debug "Webhook Auth Key: #{webhook_auth_key.inspect}"
    Rails.logger.debug "Request Body: #{request_body.inspect}"

    # Compute the expected signature
    computed_signature = OpenSSL::HMAC.hexdigest('sha256', webhook_auth_key, request_body)
    expected_auth_header = "SnapScan signature=#{computed_signature}"

    Rails.logger.debug "Computed Signature: #{computed_signature}"

    # Verify the signature
    unless Rack::Utils.secure_compare(expected_auth_header, received_auth_header)
      raise "Unauthorized webhook received"
    end
  end
end
