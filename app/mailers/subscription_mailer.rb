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
    @is_new = params[:is_new]
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

  def ad_hoc_nudge
    @subscription = params[:subscription]
    @invoice      = @subscription.invoices.where(paid: false).order(:issued_date).last
    mail(to: @subscription.user.email, subject: "Your gooi subscription is waiting for you")
  end

  def payment_reminder(stage = :day_3)
    @subscription = params[:subscription]
    @invoice      = @subscription.invoices.where(paid: false).order(:issued_date).last
    @stage        = stage

    subject = case stage
              when :day_3  then "Just a heads up — your gooi invoice is waiting"
              when :day_7  then "Your gooi subscription is still pending"
              when :day_14 then "Last nudge — your gooi invoice is overdue"
              end

    mail(to: @subscription.user.email, subject: subject)
  end

  def payment_reminder_alert(stage = :day_3)
    @subscription = params[:subscription]
    @invoice      = @subscription.invoices.where(paid: false).order(:issued_date).last
    @stage        = stage

    mail(
      to: 'howzit@gooi.me',
      subject: "Nudge sent (#{stage}) → #{@subscription.display_name}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

end
