# Tells a charging drop-off site what Gooi owes it for a month, and what Gooi
# still needs before it can pay (listed-facility letter, banking details).
# Never sent to free sites: DisposalPayment.request_for! returns nil for them.
class DisposalPaymentMailer < ApplicationMailer
  def payment_request(disposal_payment)
    @payment = disposal_payment
    @site = disposal_payment.drop_off_site
    @user = @site.user
    @amount = ActionController::Base.helpers.number_to_currency(@payment.amount, unit: "R")

    mail(
      to: @user.email,
      reply_to: "howzit@gooi.me",
      subject: "Gooi owes #{@site.name} #{@amount} for #{@payment.month_label}"
    )
  end
end
