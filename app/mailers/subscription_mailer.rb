class SubscriptionMailer < ApplicationMailer
  def subscription_completed
    @subscription = params[:subscription]
    mail(to: @subscription.user.email, subject: "Your gooi subscription is complete 🎉")
  end

  def subscription_completed_alert
    @subscription = params[:subscription]

    mail(
      to: 'howzit@gooi.me',
      subject: "Mail sent to #{@subscription.user.first_name}!",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

end
