class SendWhatsappReminderJob < ApplicationJob
  queue_as :default
  retry_on TwilioWhatsappService::TwilioError, wait: 5.minutes, attempts: 3

  def perform(user_id:, subscription_id:, collection_date:, use_template: true)
    user = User.find(user_id)
    subscription = Subscription.find(subscription_id)

    # Double-check eligibility (in case status changed since queuing)
    unless user.can_receive_whatsapp?
      Rails.logger.warn "SendWhatsappReminderJob: User #{user.email} no longer eligible"
      return
    end

    unless subscription.active?
      Rails.logger.warn "SendWhatsappReminderJob: Subscription #{subscription.id} no longer active"
      return
    end

    service = TwilioWhatsappService.new
    service.send_collection_reminder(
      user: user,
      subscription: subscription,
      collection_date: collection_date,
      use_template: use_template
    )
  rescue TwilioWhatsappService::TwilioError => e
    # Error already logged by service, will retry via retry_on
    raise
  end
end
