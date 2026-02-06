class SendWhatsappReminderJob < ApplicationJob
  queue_as :default
  retry_on TwilioWhatsappService::TwilioError, wait: 5.minutes, attempts: 3

  def perform(subscription_id:, collection_date:, use_template: true)
    subscription = Subscription.find(subscription_id)

    # Check subscription still active
    unless subscription.active?
      Rails.logger.warn "SendWhatsappReminderJob: Subscription #{subscription.id} no longer active"
      return
    end

    # Service handles sending to all contacts who can receive WhatsApp
    service = TwilioWhatsappService.new
    service.send_collection_reminder(
      subscription: subscription,
      collection_date: collection_date,
      use_template: use_template
    )
  rescue TwilioWhatsappService::TwilioError => e
    # Error already logged by service, will retry via retry_on
    raise
  end
end
