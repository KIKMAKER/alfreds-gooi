class PaymentMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  def partial_payment_alert(payment:, invoice:, user:, activated_subscription:, shortfall:, pending_subscriptions:)
    @payment = payment
    @invoice = invoice
    @user = user
    @activated_subscription = activated_subscription
    @shortfall = shortfall
    @pending_subscriptions = pending_subscriptions
    @payment_amount = payment.total_amount.to_f / 100.0

    mail(
      to: 'howzit@gooi.me',
      subject: "⚠️ Partial Payment Alert - #{user.first_name} #{user.email}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end

  def insufficient_payment_alert(payment:, invoice:, user:, required_amount:, shortfall:)
    @payment = payment
    @invoice = invoice
    @user = user
    @required_amount = required_amount
    @shortfall = shortfall
    @payment_amount = payment.total_amount.to_f / 100.0

    mail(
      to: 'howzit@gooi.me',
      subject: "❌ Insufficient Payment Alert - #{user.first_name} #{user.email}",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
end
