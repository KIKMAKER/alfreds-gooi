class CheckSubscriptionsForCompletionJob < ApplicationJob
  queue_as :default

  def perform
    Subscription.active.where(collection_day: Date.today.strftime("%A")).find_each do |subscription|
      next if subscription.start_date.blank?

      required_collections = (4.2 * subscription.duration).ceil
      completed_collections = subscription.collections.where(skip: false).count
      remaining_collections = required_collections - completed_collections


      if completed_collections >= required_collections
        subscription.completed!
        subscription.end_date!

        # Optional: Notify the customer
        SubscriptionMailer.with(subscription: subscription).subscription_completed.deliver_now
        SubscriptionMailer.with(subscription: subscription).subscription_completed_alert.deliver_now
        Rails.logger.info "Marked sub ##{subscription.id} as complete"
      elsif remaining_collections <= 2
        SubscriptionMailer.with(subscription: subscription).subscription_ending_soon.deliver_now
        SubscriptionMailer.with(subscription: subscription).subscription_ending_soon_alert.deliver_now

      end
    end
  end
end
