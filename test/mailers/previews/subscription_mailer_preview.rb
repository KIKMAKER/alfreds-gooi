class SubscriptionMailerPreview < ActionMailer::Preview
  def subscription_completed
    sub = Subscription.last || Subscription.first
    SubscriptionMailer.with(subscription: sub).subscription_completed
  end

  def welcome
    sub = Subscription.last || Subscription.first
    SubscriptionMailer.with(subscription: sub).welcome
  end
end
