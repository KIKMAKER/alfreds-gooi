class InvoiceMailer < ApplicationMailer
  # Sends the invoice to the customer and BCCs your team.
  # Expects: params[:invoice]
  def invoice_created
    @invoice      = params[:invoice]
    @subscription = @invoice.subscription
    @user         = @subscription&.user

    recipient = @user&.email.presence || "howzit@gooi.me"

    # Generate and attach PDF invoice
    pdf = InvoicePdfGenerator.new(@invoice).generate
    attachments["invoice_#{@invoice.number || @invoice.id}.pdf"] = pdf.render

    mail(
      to: recipient,
      bcc: "howzit@gooi.me",
      subject: "Your Gooi invoice ##{@invoice.number || @invoice.id}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

  # Sends an admin alert for monthly invoices
  # Expects: params[:invoice], params[:installment_number]
  def invoice_created_alert
    @invoice            = params[:invoice]
    @subscription       = @invoice.subscription
    @user               = @subscription&.user
    @installment_number = params[:installment_number]

    mail(
      to: "howzit@gooi.me",
      subject: "Monthly Invoice Generated: #{@user&.first_name} - Installment #{@installment_number}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
