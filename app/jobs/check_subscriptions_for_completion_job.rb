class CheckSubscriptionsForCompletionJob < ApplicationJob
  queue_as :default

  def perform
    Subscription.active.find_each do |subscription|
      next if subscription.start_date.blank?

      required_collections = (4.2 * subscription.duration).ceil
      completed_collections = subscription.collections.where(skip: false).count

      if completed_collections >= required_collections
        subscription.completed!

        # Optional: Notify the customer
        SubscriptionMailer.with(subscription: subscription).sub_completed.deliver_later
        Rails.logger.info "Marked sub ##{subscription.id} as complete"
      end
    end
  end
end
