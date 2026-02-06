# frozen_string_literal: true

class TwilioWhatsappService
  class TwilioError < StandardError; end

  def initialize
    @client = Twilio::REST::Client.new(
      ENV['TWILIO_ACCOUNT_SID'],
      ENV['TWILIO_AUTH_TOKEN']
    )
    @from_number = ENV['TWILIO_WHATSAPP_FROM']
    @template_sid = ENV['TWILIO_TEMPLATE_SID']
  end

  # Send WhatsApp message to all contacts for a subscription (freeform or template)
  # Returns array of WhatsappMessage records with status
  def send_collection_reminder(subscription:, collection_date:, use_template: false)
    # Get all contacts who can receive WhatsApp
    recipients = subscription.whatsapp_recipients

    if recipients.empty?
      Rails.logger.warn "No WhatsApp recipients for subscription #{subscription.id}"
      return []
    end

    messages = []

    recipients.each do |contact|
      message = if use_template
        send_template_reminder(contact: contact, subscription: subscription, collection_date: collection_date)
      else
        send_freeform_reminder(contact: contact, subscription: subscription, collection_date: collection_date)
      end

      messages << message if message
    end

    messages
  end

  # Send using Twilio template with "skip me" button
  def send_template_reminder(contact:, collection_date:, subscription:)
    return unless contact.can_receive_whatsapp?

    raise ArgumentError, "Twilio template SID not configured" unless @template_sid.present?

    # Template message body (for logging)
    message_body = "Reminder that tomorrow is gooi day! Please let us know if you will not be needing collection and we can skip you."

    whatsapp_message = WhatsappMessage.create!(
      contact: contact,
      subscription: subscription,
      user: subscription.user, # Keep for backward compatibility
      message_type: 'collection_reminder',
      message_body: message_body,
      collection_date: collection_date,
      used_template: true,
      status: 'queued'
    )

    begin
      # Build content variables for template
      # Template likely expects: contact name, collection day
      day_name = collection_date.strftime('%A')

      response = @client.messages.create(
        from: @from_number,
        to: "whatsapp:#{contact.formatted_phone}",
        content_sid: @template_sid,
        content_variables: {
          '1' => contact.first_name || 'there',
          '2' => day_name
        }.to_json
      )

      whatsapp_message.update!(
        twilio_sid: response.sid,
        status: response.status
      )

      Rails.logger.info "WhatsApp template reminder sent to #{contact.full_name} (#{contact.phone_number}): #{response.sid}"
      whatsapp_message
    rescue Twilio::REST::RestError => e
      whatsapp_message.update!(
        status: 'failed',
        error_message: e.message
      )
      Rails.logger.error "Twilio WhatsApp error for contact #{contact.id}: #{e.message}"
      raise TwilioError, e.message
    end
  end

  private

  # Send freeform message (no template, no button)
  def send_freeform_reminder(contact:, subscription:, collection_date:)
    return unless contact.can_receive_whatsapp?

    message_body = build_freeform_message(contact, subscription, collection_date)

    whatsapp_message = WhatsappMessage.create!(
      contact: contact,
      subscription: subscription,
      user: subscription.user, # Keep for backward compatibility
      message_type: 'collection_reminder',
      message_body: message_body,
      collection_date: collection_date,
      used_template: false,
      status: 'queued'
    )

    begin
      response = @client.messages.create(
        from: @from_number,
        to: "whatsapp:#{contact.formatted_phone}",
        body: message_body
      )

      whatsapp_message.update!(
        twilio_sid: response.sid,
        status: response.status
      )

      Rails.logger.info "WhatsApp freeform reminder sent to #{contact.full_name} (#{contact.phone_number}): #{response.sid}"
      whatsapp_message
    rescue Twilio::REST::RestError => e
      whatsapp_message.update!(
        status: 'failed',
        error_message: e.message
      )
      Rails.logger.error "Twilio WhatsApp error for contact #{contact.id}: #{e.message}"
      raise TwilioError, e.message
    end
  end

  def build_freeform_message(contact, subscription, collection_date)
    day_name = collection_date.strftime('%A')
    plan_emoji = subscription.Standard? ? '🗑️' : (subscription.XL? ? '🪣' : '🏢')

    <<~MSG.strip
      Hi #{contact.first_name}! 👋

      Just a friendly reminder that your gooi collection is tomorrow (#{day_name})! #{plan_emoji}

      Plan: #{subscription.plan}

      Please leave your #{plan_description(subscription)} outside before 7am.

      Questions? Reply to this message or visit alfred.gooi.me

      Keep gooiing! 💚
    MSG
  end

  def plan_description(subscription)
    case subscription.plan
    when 'Standard'
      'bag(s)'
    when 'XL'
      'bucket(s)'
    when 'Commercial'
      "#{subscription.buckets_per_collection}x #{subscription.bucket_size}L bucket(s)"
    else
      'collection'
    end
  end

  def format_whatsapp_number(phone_number)
    # User phone numbers should already be international format (e.g., +27812345678)
    # Twilio requires whatsapp: prefix
    clean_number = phone_number.gsub(/\D/, '')
    clean_number = "+#{clean_number}" unless clean_number.start_with?('+')
    "whatsapp:#{clean_number}"
  end
end
