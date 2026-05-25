class UserMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  def welcome
    @subscription = params[:subscription]
    recipient = params[:to_email].presence || @subscription.user.email

    mail(
      to: recipient,
      subject: 'Welcome to Gooi!',
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

  def sign_up_alert
    @subscription = params[:subscription]

    mail(
      to: 'howzit@gooi.me',
      subject: "New Sign Up from #{@subscription.user.first_name}!",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
