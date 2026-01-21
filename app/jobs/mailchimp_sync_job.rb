# frozen_string_literal: true

class MailchimpSyncJob < ApplicationJob
  queue_as :default

  retry_on Gibbon::MailChimpError, wait: 5.minutes, attempts: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    MailchimpSyncService.sync_user(user)
  end
end
