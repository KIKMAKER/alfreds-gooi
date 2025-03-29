# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:snapscan_webhook, :fetch_snapscan_payments]
  skip_before_action :authenticate_user!, only: [:snapscan_webhook, :fetch_snapscan_payments]

  def index
    Snapscan::SyncService.new(ENV['SNAPSCAN_API_KEY']).sync!
    @payments = Payment.all.order(date: :desc)
  end

  def show
    @payment = Payment.find(params[:id])
  end

  def snapscan_webhook
    begin
      raw_body = request.raw_post
      verify_signature(raw_body, ENV['WEBHOOK_AUTH_KEY'])
      json = Rack::Utils.parse_nested_query(raw_body)["payload"]
      payload = JSON.parse(json)

      result = Snapscan::WebhookHandler.new(payload).process!

      case result
      when :success
        render json: { status: 'success' }, status: :ok
      when :failed
        render json: { status: 'failed', message: 'Payment was not successful' }, status: :ok
      when :ignored
        render json: { status: 'ignored', message: 'Unhandled payment status' }, status: :ok
      else
        render json: { error: 'Unknown error' }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "💥 Error processing SnapScan webhook: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def fetch_snapscan_payments
    api_key = ENV['SNAPSCAN_API_KEY']
    service = SnapscanService.new(api_key)
    payments = service.fetch_payments

    if payments
      render json: payments, status: :ok
    else
      render json: { error: 'Failed to fetch payments' }, status: :unprocessable_entity
    end
  end

  private

  def verify_signature(raw_body, webhook_auth_key)
    return true if Rails.env.test?
    Rails.logger.debug "🔐 Raw body: #{raw_body}"

    received_auth_header = request.headers['Authorization'].to_s
    received_signature = received_auth_header.split('=').last

    computed_signature = OpenSSL::HMAC.hexdigest('sha256', webhook_auth_key, raw_body)

    unless Rack::Utils.secure_compare(received_signature, computed_signature)
      raise "Unauthorized webhook received – signature mismatch"
    end
  end
end
