class InvoicesController < ApplicationController

  def new
    @subscription = Subscription.find(params[:subscription_id])
    @invoice = Invoice.new
    @products = Product.all
  end

  def create
    subscription = Subscription.find(params[:subscription_id])
    invoice = Invoice.new(issued_date: Time.current, due_date: Time.current + 1.month)
    invoice.subscription = subscription
    invoice_item = InvoiceItem.new(invoice_item_params)
    invoice_item.invoice = invoice
    if invoice.save && invoice_item.save
      redirect_to subscription_invoice_path(subscription, invoice)
    else
      render :new
    end
  end

  def show
    @subscription = Subscription.find(params[:subscription_id])
    @invoice = @subscription.invoices.first
  end

  private

  def invoice_item_params
    # params.require(:invoice).permit(:issued_date, :due_date, :subscription_id)
    params.require(:invoice_items).permit(:product_id, :quantity)
  end
end
