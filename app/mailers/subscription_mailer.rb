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

  def subscription_completed_with_renewal
    @subscription = params[:subscription]
    mail(to: @subscription.user.email, subject: "Your gooi subscription is complete 🎉")
  end

  def subscription_completed_with_renewal_alert
    @subscription = params[:subscription]

    mail(
      to: 'howzit@gooi.me',
      subject: "Mail sent to #{@subscription.user.first_name}!",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

  def subscription_ending_soon
    @subscription = params[:subscription]
    mail(to: @subscription.user.email, subject: "Your gooi subscription is almost up!")
  end

  def subscription_ending_soon_alert
    @subscription = params[:subscription]

    mail(
      to: 'howzit@gooi.me',
      subject: "Mail sent to #{@subscription.user.first_name}!",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

  def payment_received
    @subscription = params[:subscription]
    @user = @subscription.user
    mail(to: @user.email, subject: "Payment received - your gooi subscription is now active!")
  end

  def referral_completed
    @referrer = params[:referrer]
    @referee  = params[:referee]
    mail(to: @referrer.email, subject: "#{@referee.first_name} just joined gooi — you've earned R50!")
  end

  def payment_received_alert
    @subscription = params[:subscription]

    mail(
      to: 'howzit@gooi.me',
      subject: "Payment received email sent to #{@subscription.user.first_name}!",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

end
