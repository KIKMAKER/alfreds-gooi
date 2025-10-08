class InterestMailer < ApplicationMailer
  default to: ENV["INTEREST_NOTIFY_TO"] || "howzit@gooi.me",
          from: ENV["MAIL_FROM"] || "howzit@gooi.me"

  def new_interest_email
    @interest = params[:interest]
    mail(
      subject: "New Gooi interest: #{@interest.name} (#{@interest.suburb})",
      reply_to: @interest.email
    )
  end
end
