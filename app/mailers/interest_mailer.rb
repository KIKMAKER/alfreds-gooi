class InterestMailer < ApplicationMailer
  default to: ENV["INTEREST_NOTIFY_TO"] || "you@example.com",
          from: ENV["MAIL_FROM"] || "no-reply@your-domain"

  def new_interest_email
    @interest = params[:interest]
    mail(
      subject: "New Gooi interest: #{@interest.name} (#{@interest.suburb})",
      reply_to: @interest.email
    )
  end
end
