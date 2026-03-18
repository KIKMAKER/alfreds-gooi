class InterestMailer < ApplicationMailer
  # Notify admin of new interest
  def new_interest_email
    @interest = params[:interest]
    mail(
      to: ENV["INTEREST_NOTIFY_TO"] || "howzit@gooi.me",
      from: ENV["MAIL_FROM"] || "howzit@gooi.me",
      subject: "New Gooi interest: #{@interest.name} (#{@interest.suburb})",
      reply_to: @interest.email
    )
  end

  # Confirmation to the person who submitted
  def confirmation_email
    @interest = params[:interest]
    @first_name = @interest.name.split.first
    mail(
      to: @interest.email,
      from: ENV["MAIL_FROM"] || "howzit@gooi.me",
      subject: "We've noted your interest, #{@first_name} 🌱"
    )
  end
end
