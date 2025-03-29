# app/services/snapscan/api_client.rb
require 'net/http'
require 'openssl'

module Snapscan
  class ApiClient
    SNAPSCAN_URL = "https://pos.snapscan.io/merchant/api/v1/payments"

    def initialize(api_key)
      @api_key = api_key
      @uri = URI(SNAPSCAN_URL)
    end

    def fetch_payments
      Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_PEER) do |http|
        request = Net::HTTP::Get.new @uri.request_uri
        request.basic_auth @api_key, ""
        response = http.request request

        if response.is_a?(Net::HTTPSuccess)
          Rails.logger.info "📥 SnapScan API response received"
          JSON.parse(response.body)
        else
          Rails.logger.error "❌ SnapScan API Request failed: #{response.code} #{response.message}"
          nil
        end
      end
    end

    # Optional legacy helper if you're still using this:
    def reconcile_old_payments
      payments = fetch_payments
      return unless payments

      payments.each do |payment|
        next if Payment.exists?(snapscan_id: payment['id'])

        Payment.create!(
          snapscan_id: payment['id'],
          amount: payment['amount'],
          status: payment['status'],
          timestamp: payment['timestamp'],
          reference: payment['reference']
        )
      end

      Rails.logger.info "✅ Reconciliation complete. Persisted payments: #{payments.count}"
    end
  end
end
