class WhatsappReminderJob < ApplicationJob
  queue_as :default

  def perform(date = nil, use_template: true)
    # Default to tomorrow if no date provided
    target_date = date&.to_date || Date.tomorrow
    day_name = target_date.wday  # Ruby wday (0=Sunday, 1=Monday, etc.)

    Rails.logger.info "WhatsappReminderJob: Processing reminders for #{target_date} (#{Date::DAYNAMES[day_name]})"
    Rails.logger.info "Using #{use_template ? 'template' : 'freeform'} messages"

    # Find all active subscriptions for this collection day
    subscriptions = Subscription.active
                                .includes(:user)
                                .where(collection_day: day_name)

    eligible_count = 0
    skipped_count = 0

    subscriptions.each do |subscription|
      user = subscription.user

      # Skip if user can't receive WhatsApp (no phone or opted out)
      unless user.can_receive_whatsapp?
        skipped_count += 1
        Rails.logger.debug "Skipping #{user.email}: #{user.phone_number.blank? ? 'no phone' : 'opted out'}"
        next
      end

      # Queue individual send job
      SendWhatsappReminderJob.perform_later(
        user_id: user.id,
        subscription_id: subscription.id,
        collection_date: target_date,
        use_template: use_template
      )
      eligible_count += 1
    end

    Rails.logger.info "WhatsappReminderJob complete: #{eligible_count} reminders queued, #{skipped_count} skipped"
  end
end
