class InvoiceMailer < ApplicationMailer
  # Sends the invoice to the customer and BCCs your team.
  # Expects: params[:invoice]
  def invoice_created
    @invoice      = params[:invoice]
    @subscription = @invoice.subscription
    @user         = @subscription&.user

    recipient = @user&.email.presence || "howzit@gooi.me"

    mail(
      to: recipient,
      bcc: "howzit@gooi.me",
      subject: "Your Gooi invoice ##{@invoice.number || @invoice.id}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
