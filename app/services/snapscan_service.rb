# app/services/snapscan_service.rb
require 'net/http'
require 'openssl'

class SnapscanService
  SNAPSCAN_URL = "https://pos.snapscan.io/merchant/api/v1/payments"

  def initialize(api_key)
    @api_key = api_key
    @uri = URI(SNAPSCAN_URL)
  end

  def reconcile_old_payments
    payments = fetch_payments
    return unless payments

    payments.each do |payment|
      next if Payment.exists?(snapscan_id: payment['id']) # Skip if already persisted

      Payment.create!(
        snapscan_id: payment['id'],
        amount: payment['amount'],
        status: payment['status'],
        timestamp: payment['timestamp'],
        reference: payment['reference']
      )
    end

    puts "Reconciliation complete. Persisted payments: #{payments.count}"
  end

  def fetch_payments
    Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_PEER) do |http|
      request = Net::HTTP::Get.new @uri.request_uri
      request.basic_auth @api_key, ""
      response = http.request request

      if response.is_a?(Net::HTTPSuccess)
        puts response.body
        JSON.parse(response.body)
      else
        puts "HTTP Request failed (#{response.code} #{response.message})"
        nil
      end
    end
  end
end
