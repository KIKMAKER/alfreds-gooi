class UserMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  def welcome
    @subscription = params[:subscription]

    mail(
      to: @subscription.user.email,
      subject: 'Welcome to Gooi!',
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
