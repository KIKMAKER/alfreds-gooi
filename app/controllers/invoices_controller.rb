class InvoicesController < ApplicationController

  def new
    @subscription = Subscription.find(params[:subscription_id])
    @invoice = Invoice.new
    @products = Product.all
  end

  def create
    subscription = Subscription.find(params[:subscription_id])
    @invoice = Invoice.new(issued_date: Time.current, due_date: Time.current + 1.month, total_amount: 0)
    @invoice.subscription = subscription
    # invoice_item = InvoiceItem.new(invoice_item_params)
    # invoice_item.amount = Product.find(invoice_item_params[:product_id]).price

    # invoice_item.invoice = invoice
    # invoice.calculate_total
    if @invoice.save
      create_invoice_items(@invoice)
      @invoice.calculate_total
      redirect_to subscription_invoice_path(subscription, @invoice), notice: 'Invoice was successfully created.'
    else
      @products = Product.all  # Re-fetch products in case of validation errors
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @subscription = Subscription.find(params[:subscription_id])
    @invoice = Invoice.find(params[:id])
  end

  private

  def invoice_items_params
    # params.require(:invoice).permit(:issued_date, :due_date, :subscription_id)
    params.require(:invoice_items).permit(product_id: [], quantity: [])
  end

  def create_invoice_items(invoice)
    invoice_items_params[:product_id].each_with_index do |product_id, index|
      product = Product.find(product_id)
      quantity = invoice_items_params[:quantity][index].to_f
      unless quantity == 0
        invoice.invoice_items.create!(
          product_id: product.id,
          quantity: quantity,
          amount: product.price * quantity
        )
      end
    end
  end
end
