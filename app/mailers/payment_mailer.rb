class PaymentMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  def short_payment_alert(payment:, invoice:, user:, shortfall:)
    @payment        = payment
    @invoice        = invoice
    @user           = user
    @shortfall      = shortfall
    @payment_amount = payment.total_amount.to_f / 100.0
    @invoice_total  = invoice.total_amount.to_f

    mail(
      to: 'howzit@gooi.me',
      subject: "⚠️ Short payment — #{user.first_name} #{user.last_name} (#{user.customer_id})",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
