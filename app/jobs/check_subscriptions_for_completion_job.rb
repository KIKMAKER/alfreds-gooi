class CheckSubscriptionsForCompletionJob < ApplicationJob
  queue_as :default
  OVERLAP_BACK_DAYS   = 27
  FUTURE_FORWARD_DAYS = 45

  def perform
    # NOTE: if collection_day is an enum (integer), change this filter accordingly.
    today_name = Date.today.strftime("%A")

    Subscription.active.where(collection_day: today_name).find_each do |subscription|
      next if subscription.start_date.blank?

      required_collections   = (4 * subscription.duration).ceil
      completed_collections  = subscription.collections.where(skip: false).count
      remaining_collections  = required_collections - completed_collections

      # Is there an overlapping or upcoming subscription for this user?
      has_next = user_has_overlapping_or_upcoming_subscription?(subscription,
                                                back_days: OVERLAP_BACK_DAYS,
                                                forward_days: FUTURE_FORWARD_DAYS)

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

      elsif remaining_collections <= 2
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

  # “Future sub” means:
  # - another subscription for the same user (not this one)
  # - that either overlaps *now* (start_date in the last few days), or starts within the next N days
  #
  # This avoids looking too far back (your original `from: Date.today - 14`),
  # but still catches overlap that began very recently (3-day grace).

  def user_has_overlapping_or_upcoming_subscription?(subscription,
                                                back_days: OVERLAP_BACK_DAYS,
                                                forward_days: FUTURE_FORWARD_DAYS)
    user = subscription.user
    from = Date.today - back_days
    to   = Date.today + forward_days

    user.subscriptions
        .where.not(id: subscription.id)
        .where.not(start_date: nil)
        .where(start_date: from..to)
        .exists?
  end
end
