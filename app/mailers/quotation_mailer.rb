class QuotationMailer < ApplicationMailer
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
