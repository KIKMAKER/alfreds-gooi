class CheckSubscriptionsForCompletionJob < ApplicationJob
  queue_as :default

  def perform
    # NOTE: if collection_day is an enum (integer), change this filter accordingly.
    today_name = Date.today.strftime("%A")

    Subscription.active.where(collection_day: today_name).find_each do |subscription|
      next if subscription.start_date.blank?

      required_collections   = (4 * subscription.duration).ceil + 1
      completed_collections  = subscription.collections.where(skip: false).count
      remaining_collections  = required_collections - completed_collections

      # Calculate alert threshold based on subscription duration
      # 1-month: alert with 1 left, 3-month: 2 left, 6+ months: 3 left
      alert_threshold = case subscription.duration
                        when 1
                          1
                        when 3
                          2
                        when 6, 12
                          3
                        else
                          2
                        end

      # Is there an overlapping or upcoming subscription for this user?
      has_next = user_has_overlapping_or_upcoming_subscription?(subscription)

      if completed_collections >= required_collections
        # 1) COMPLETE regardless of future subs
        subscription.completed!
        subscription.end_date!

        if has_next
          # customer has resubscribed - send thank you email (no resubscribe CTA)
          SubscriptionMailer.with(subscription: subscription).subscription_completed_with_renewal.deliver_now
          SubscriptionMailer.with(subscription: subscription).subscription_completed_with_renewal_alert.deliver_now
        else
          # customer hasn't resubscribed - send email with resubscribe CTA
          SubscriptionMailer.with(subscription: subscription).subscription_completed.deliver_now
          SubscriptionMailer.with(subscription: subscription).subscription_completed_alert.deliver_now
        end
        Rails.logger.info "Marked sub ##{subscription.id} as complete (future_sub=#{has_next})"

      elsif remaining_collections <= alert_threshold
        # 2) Ending soon nudges (only if no future sub to avoid spam)
        if has_next
          Rails.logger.info "Muted ending-soon emails for sub ##{subscription.id} (future_sub=true)"
        elsif subscription.ending_soon_emailed_at == Date.today
          Rails.logger.info "Skipped ending-soon emails for sub ##{subscription.id} (already emailed today)"
        else
          SubscriptionMailer.with(subscription: subscription).subscription_ending_soon.deliver_now
          SubscriptionMailer.with(subscription: subscription).subscription_ending_soon_alert.deliver_now
          subscription.update_column(:ending_soon_emailed_at, Date.today)
          Rails.logger.info "Ending-soon emails sent for sub ##{subscription.id}"
        end

      else
        # 3) Not close to ending; do nothing
        Rails.logger.debug "No-op for sub ##{subscription.id} (remaining=#{remaining_collections})"
      end
    end
  end

  private

  # "Future sub" means:
  # - another subscription for the same user (not this one)
  # - that is pending/active status, OR has a future start_date
  #
  # FIXED: No longer uses created_at date range (was missing recent resubscribes)
  # Now checks actual subscription status and start_date

  def user_has_overlapping_or_upcoming_subscription?(subscription)
    user = subscription.user

    user.subscriptions
        .where.not(id: subscription.id)
        .where(status: [:pending, :active])
        .or(
          user.subscriptions
              .where.not(id: subscription.id)
              .where("start_date IS NOT NULL AND start_date > ?", Date.today)
        )
        .exists?
  end
end
