class InvoicesController < ApplicationController

  def index
    if current_user.admin?
      @invoices = Invoice.all
    elsif current_user.customer?
      @invoices = current_user.invoices
    end
  end
  def new
    @invoice = Invoice.new
    @products = Product.all
    @invoice.invoice_items.build
  end

  def create
    @invoice = Invoice.new(issued_date: Time.current, due_date: Time.current + 1.month, total_amount: 0)
    @invoice.subscription = Subscription.find(params[:invoice][:subscription_id])
    @invoice.save!
    if @invoice.update(issued_date: Time.current, due_date: Time.current + 1.month, total_amount: 0)

      create_invoice_items(@invoice)
      @invoice.calculate_total
      redirect_to invoice_path(@invoice), notice: 'Invoice was successfully created.'
    else
      @products = Product.all  # Re-fetch products in case of validation errors
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @invoice = Invoice.find(params[:id])
    @subscription = @invoice.subscription
    @referrer_discount = Product.find_by(title: "Referred a friend discount")
    
  end

  private

  def invoice_items_params
    # params.require(:invoice).permit(:issued_date, :due_date, :subscription_id)
    params.require(:invoice).permit(:subscription_id, invoice_items_attributes: [ :product_id, :quantity ])
  end

  def create_invoice_items(invoice)
    invoice_items_params[:invoice_items_attributes].each do |index, product_hash|
      product = Product.find(product_hash[:product_id])
      quantity = product_hash[:quantity]
      next if quantity.blank? || quantity.to_f <= 0

      invoice.invoice_items.create!(
        product_id: product.id,
        quantity: quantity,
        amount: product.price * quantity.to_f
      )

    end
    # [:product_id]
    # quantities = invoice_items_params[:invoice_items_attributes][:quantity]

    # product_ids.each_with_index do |product_id, index|
    # product = Product.find(product_id)
    # quantity = quantities[index].to_f
    #   unless quantity == 0
    #     invoice.invoice_items.create!(
    #       product_id: product.id,
    #       quantity: quantity,
    #       amount: product.price * quantity
    #     )
    #   end
  end
end
