class Admin::InvoicesController < Admin::BaseController
  before_action :authenticate_user!

  def approve
    @invoice = Invoice.find(params[:id])

    if @invoice.admin_approved?
      redirect_to admin_root_path, alert: "Invoice ##{@invoice.number} was already approved and sent."
      return
    end

    @invoice.update!(admin_approved: true)

    InvoiceMailer.with(invoice: @invoice).invoice_created.deliver_now

    redirect_to admin_root_path,
      notice: "Invoice ##{@invoice.number} approved and sent to #{@invoice.subscription&.user&.email}."
  end
end
