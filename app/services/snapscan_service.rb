# app/services/snapscan_service.rb
require 'net/http'
require 'openssl'

class SnapscanService
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
        puts response.body
        JSON.parse(response.body)
      else
        puts "HTTP Request failed (#{response.code} #{response.message})"
        nil
      end
    end
  end
end
