# frozen_string_literal: true

if ENV['MAILCHIMP_API_KEY'].present?
  # Initialize Gibbon (Mailchimp Ruby client)
  Gibbon::Request.api_key = ENV['MAILCHIMP_API_KEY']
  Gibbon::Request.timeout = 15

  # Extract server prefix from API key (e.g., "abc123-us19" -> "us19")
  server_prefix = ENV['MAILCHIMP_API_KEY'].split('-').last

  Rails.logger.info "Mailchimp initialized with server: #{server_prefix}"
else
  Rails.logger.warn "MAILCHIMP_API_KEY not set - Mailchimp integration disabled"
end
