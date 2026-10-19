# Sends a site its "here's what we owe you" email, and records when we've paid.
class Admin::DisposalPaymentsController < Admin::BaseController
  def create
    site = DropOffSite.find_by!(slug: params[:site])
    month = Date.strptime(params[:month], "%Y-%m")

    unless site.user
      return redirect_to(admin_disposal_fees_path, alert: "#{site.name} has no manager account to email.")
    end

    payment = DisposalPayment.request_for!(site, month: month)
    return redirect_to(admin_disposal_fees_path, alert: "Nothing to pay #{site.name} for #{month.strftime('%B %Y')}.") unless payment

    DisposalPaymentMailer.payment_request(payment).deliver_now
    redirect_to admin_disposal_fees_path, notice: "Payment request for #{payment.month_label} sent to #{site.name}."
  end

  def mark_paid
    payment = DisposalPayment.find(params[:id])
    payment.mark_paid!
    redirect_to admin_disposal_fees_path, notice: "#{payment.drop_off_site.name} marked as paid for #{payment.month_label}."
  rescue DisposalPayment::NotPayable => e
    redirect_to admin_disposal_fees_path, alert: "Can't pay yet: #{e.message}."
  end
end
