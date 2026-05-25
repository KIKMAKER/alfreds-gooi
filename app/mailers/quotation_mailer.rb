class QuotationMailer < ApplicationMailer
  # Notifies admin that a quotation has been accepted and needs converting to a subscription.
  # Expects: params[:quotation]
  def accepted
    @quotation = params[:quotation]

    mail(
      to: "howzit@gooi.me",
      subject: "✅ Quote ##{@quotation.number} accepted — #{@quotation.customer_name} needs a subscription",
      message_stream: 'outbound'
    )
  end

  # Sends the quotation to the customer/prospect and BCCs your team.
  # Expects: params[:quotation]
  def quotation_created
    @quotation = params[:quotation]
    @user      = @quotation.user

    recipient = @quotation.customer_email.presence || "howzit@gooi.me"

    # Generate and attach PDF quotation
    pdf = QuotationPdfGenerator.new(@quotation).generate
    attachments["quotation_#{@quotation.number || @quotation.id}.pdf"] = pdf.render

    mail(
      to: recipient,
      bcc: "howzit@gooi.me",
      subject: "Your Gooi quotation ##{@quotation.number || @quotation.id}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
