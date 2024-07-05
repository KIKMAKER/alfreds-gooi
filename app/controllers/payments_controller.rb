class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:receive]
  skip_before_action :verify_authenticity_token

  def snapscan_webhook
    raise
    request_body = request.body.read
    verify_signature!(request_body, ENV['WEBHOOK_AUTH_KEY'])
    payload = JSON.parse(params[:payload])
    puts ">>> Received payload: #{payload.inspect}"

    # handle payload logic here, i.e inspect the payload and update the subscription

  end

  private

  def verify_signature(request_body, webhook_auth_key)
    signature = OpenSSL::HMAC.hexdigest('sha256', webhook_auth_key, request_body)
    auth_signature = "SnapScan signature=#{signature}"

    unless Rack::Utils.secure_compare(auth_signature, request.headers['Authorization'])
      raise "Unauthorized webhook received"
    end
  end

end
