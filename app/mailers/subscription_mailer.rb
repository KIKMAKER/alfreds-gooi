class SubscriptionMailer < ApplicationMailer
  def subscription_completed
    @subscription = params[:subscription]
    mail(to: @subscription.user.email, subject: "Your gooi subscription is complete 🎉")
  end
end
