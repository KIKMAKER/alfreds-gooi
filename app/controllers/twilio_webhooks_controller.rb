class TwilioWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def whatsapp_reply
    # Verify Twilio signature for security
    unless verify_twilio_signature
      Rails.logger.error "TwilioWebhooksController: Invalid signature"
      head :forbidden
      return
    end

    from_number = extract_phone_number(params['From'])
    button_payload = params['ButtonPayload']

    Rails.logger.info "TwilioWebhooksController: Received webhook from #{from_number}, button: #{button_payload}"

    # Handle "skip me" button click
    if button_payload == 'skip_1'
      handle_skip_request(from_number)
    else
      Rails.logger.warn "TwilioWebhooksController: Unknown button payload: #{button_payload}"
    end

    # Return empty TwiML (no auto-reply)
    render xml: '<?xml version="1.0" encoding="UTF-8"?><Response></Response>'
  end

  private

  def verify_twilio_signature
    return true if Rails.env.development? && ENV['SKIP_TWILIO_SIGNATURE_VERIFICATION'] == 'true'

    validator = Twilio::Security::RequestValidator.new(ENV['TWILIO_AUTH_TOKEN'])
    signature = request.headers['X-Twilio-Signature']
    url = request.original_url
    params_hash = request.POST

    validator.validate(url, params_hash, signature)
  end

  def extract_phone_number(from_param)
    # Twilio sends "whatsapp:+27812345678"
    # Extract just the phone number
    from_param.gsub('whatsapp:', '')
  end

  def handle_skip_request(phone_number)
    user = User.find_by(phone_number: phone_number)

    unless user
      Rails.logger.error "TwilioWebhooksController: No user found with phone #{phone_number}"
      return
    end

    # Find collection for tomorrow
    collection = user.collections.where(date: Date.tomorrow).first

    unless collection
      Rails.logger.error "TwilioWebhooksController: No collection found for #{user.email} on #{Date.tomorrow}"
      return
    end

    # Mark as skipped using existing method (sends email notification)
    collection.mark_skipped!(by: nil, reason: 'customer_whatsapp_button')

    Rails.logger.info "TwilioWebhooksController: Marked collection #{collection.id} as skipped for #{user.email}"
  end
end
