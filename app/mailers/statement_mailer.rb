class StatementMailer < ApplicationMailer
  # Sends the account statement to the customer and BCCs your team.
  # Expects: params[:user]
  def statement_created
    @user = params[:user]
    @invoices = @user.invoices.includes(subscription: :user).order(issued_date: :desc)
    @total_invoiced = @invoices.sum(:total_amount)
    @total_paid = @invoices.where(paid: true).sum(:total_amount)
    @balance_owing = @total_invoiced - @total_paid

    recipient = @user.email.presence || "howzit@gooi.me"

    # Generate and attach PDF statement
    pdf = StatementPdfGenerator.new(@user).generate
    attachments["statement_#{@user.id}_#{Date.today.strftime('%Y%m%d')}.pdf"] = pdf.render

    mail(
      to: recipient,
      bcc: "howzit@gooi.me",
      subject: "Your Gooi Account Statement",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
