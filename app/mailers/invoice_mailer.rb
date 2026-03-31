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

  # Sends an admin approval request for monthly invoices.
  # Admin must click "Approve & Send" before the customer receives the invoice.
  # Expects: params[:invoice], params[:installment_number]
  def invoice_pending_approval
    @invoice            = params[:invoice]
    @subscription       = @invoice.subscription
    @user               = @subscription&.user
    @installment_number = params[:installment_number]
    @approve_url        = approve_admin_invoice_url(@invoice)

    mail(
      to: "howzit@gooi.me",
      subject: "Action required: Approve invoice for #{@user&.first_name} — Installment #{@installment_number} (R#{number_with_precision(@invoice.total_amount.to_f, precision: 2)})",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
