# frozen_string_literal: true

if ENV['TWILIO_ACCOUNT_SID'].present? && ENV['TWILIO_AUTH_TOKEN'].present?
  require 'twilio-ruby'

  Rails.logger.info "Twilio initialized for WhatsApp messaging"
  Rails.logger.info "Using WhatsApp number: #{ENV['TWILIO_WHATSAPP_FROM']}"

  if ENV['TWILIO_TEMPLATE_SID'].present?
    Rails.logger.info "Twilio template configured: #{ENV['TWILIO_TEMPLATE_SID']}"
  end
else
  Rails.logger.warn "TWILIO credentials not set - WhatsApp messaging disabled"
end
