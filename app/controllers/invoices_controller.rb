class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show update destroy paid]

  def index
    if current_user.admin?
      @invoices = Invoice.includes(subscription: :user).order(issued_date: :desc)
    elsif current_user.customer?
      @invoices = current_user.invoices.includes(subscription: :user).order(issued_date: :desc)
    end
  end
  def new
    @invoice = Invoice.new
    @products = Product.all
    @invoice.invoice_items.build
  end

  def create
    @invoice = Invoice.new
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

  def update
    @invoice = Invoice.find(params[:id])
    create_invoice_items(@invoice)

    redirect_to invoice_path(@invoice)
  end

  def show
    # @invoice = Invoice.find(params[:id])
    @subscription = @invoice.subscription
  end

  def destroy
    # @invoice = Invoice.find(params[:id])
    @invoice.destroy
    redirect_to invoices_path
  end

  def bags
    @subscription = current_user.subscriptions.last
    @invoice = Invoice.create(issued_date: Time.current, due_date: Time.current + 1.week, total_amount: 0, subscription_id: @subscription.id)
    bags = params[:bags].to_i
    product = Product.find_by(title: "Compost bin bags")
    @invoice.invoice_items.create!(
      product_id: product.id,
      quantity: bags,
      amount: product.price
    )
    @invoice.calculate_total
  end

  def paid
    # @invoice = Invoice.find(params[:id])
    if @invoice.update!(paid: true)
      @invoice.subscription.active!
      redirect_to invoice_path(@invoice)
    else
      render :show, status: "An error occured the invoice is #{@invoice.paid ? 'paid' : 'not paid' }"
    end
  end

  private

  def invoice_items_params
    # params.require(:invoice).permit(:issued_date, :due_date, :subscription_id)
    params.require(:invoice).permit(invoice_items_attributes: [ :product_id, :quantity ])
  end

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def create_invoice_items(invoice)
    invoice_items_params[:invoice_items_attributes].each do |index, product_hash|
      product = Product.find(product_hash[:product_id])
      quantity = product_hash[:quantity].to_f
      next if quantity.blank? || quantity <= 0

      invoice.invoice_items.create!(
        product_id: product.id,
        quantity: quantity,
        amount: product.price
      )
    end
    invoice.calculate_total

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
