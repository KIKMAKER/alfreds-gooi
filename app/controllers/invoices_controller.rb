class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy paid issued_bags send apply_discount_code]

  def index
    if current_user.admin?
      @invoices = Invoice.includes(subscription: :user).order(issued_date: :desc)

      # Filter by user if user_id param is present
      if params[:user_id].present?
        @user = User.find(params[:user_id])
        @invoices = @invoices.joins(subscription: :user).where(users: { id: @user.id })
      end
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
    if @invoice.update(issued_date: Time.current, due_date: Time.current + 1.week)

      create_invoice_items(@invoice)
      @invoice.calculate_total
      redirect_to invoice_path(@invoice), notice: 'Invoice was successfully created.'
    else
      @products = Product.all # Re-fetch products in case of validation errors
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = Product.all
    @invoice.invoice_items.build if @invoice.invoice_items.empty?
  end

  def update
    if params[:invoice][:invoice_items_attributes].present?
      # Handle updates and deletions via nested attributes
      @invoice.update(invoice_params)

      # Handle new items manually
      params[:invoice][:invoice_items_attributes].each do |key, item_params|
        next unless key.to_s.start_with?('new_')
        next if item_params[:quantity].blank? || item_params[:quantity].to_f <= 0

        product = Product.find(item_params[:product_id])
        @invoice.invoice_items.create!(
          product_id: product.id,
          quantity: item_params[:quantity].to_f,
          amount: product.price
        )
      end

      @invoice.calculate_total
      @subscription = @invoice.subscription
      redirect_to invoice_path(@invoice), notice: 'Invoice was successfully updated.'
    else
      # Legacy behavior for issued_bags route
      create_invoice_items(@invoice)
      redirect_to invoice_path(@invoice)
    end
  end

  def show
    # @invoice = Invoice.find(params[:id])
    @subscription = @invoice.subscription
    @referrer_discount = Product.find_by(title: "Referred a friend discount")
    @discount_code = DiscountCode.find_by(code: @subscription.discount_code&.upcase) if @invoice.used_discount_code?
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
    user = @invoice.subscription.user
    pending_subscriptions = user.subscriptions.where(status: :pending)
    active_subscriptions = user.subscriptions.where(status: :active, is_paused: false)

    ActiveRecord::Base.transaction do
      @invoice.update!(paid: true)

      pending_subscriptions.each do |subscription|
        subscription.activate_subscription

        # Create first collection for each subscription
        first_collection = CreateFirstCollectionJob.perform_now(subscription)


      end
    end

    count = active_subscriptions.count
    flash[:notice] = "Payment recorded! #{count} #{'subscription'.pluralize(count)} activated."
    redirect_to invoice_path(@invoice)
  rescue StandardError => e
    flash[:alert] = "An error occurred: #{e.message}"
    redirect_to invoice_path(@invoice)
  end

  def issued_bags
    @subscription = @invoice.subscription
    create_invoice_items(@invoice)
    @invoice.save!
    redirect_to send_invoice_path(@invoice)
  end

  def apply_discount_code
    unless current_user.admin?
      redirect_to invoice_path(@invoice), alert: "Only admins can apply discount codes"
      return
    end

    code_string = params[:discount_code]&.strip&.upcase
    code = DiscountCode.find_by(code: code_string)

    unless code
      redirect_to invoice_path(@invoice), alert: "Discount code '#{code_string}' not found"
      return
    end

    # Check if already applied
    if @invoice.invoice_discount_codes.where(discount_code: code).exists?
      redirect_to invoice_path(@invoice), alert: "This discount code is already applied to this invoice"
      return
    end

    # Validate 3-month restriction if applicable
    if code.three_month_only? && @invoice.subscription.duration != 3
      redirect_to invoice_path(@invoice), alert: "This discount code is only valid for 3-month subscriptions"
      return
    end

    # Calculate discount amount
    subtotal = @invoice.invoice_items.sum { |item| item.amount * item.quantity }

    discount_amount = if code.percentage_based?
      percent_off = code.discount_percent.clamp(0, 100)
      (subtotal * percent_off / 100.0).round(2)
    elsif code.fixed_amount?
      (code.discount_cents / 100.0).round(2)
    else
      0
    end

    # Don't apply discount if it would make total negative
    discount_amount = subtotal if discount_amount > subtotal

    if discount_amount <= 0
      redirect_to invoice_path(@invoice), alert: "Discount code results in R0 discount"
      return
    end

    # Apply the discount
    ActiveRecord::Base.transaction do
      @invoice.invoice_discount_codes.create!(
        discount_code: code,
        discount_amount: discount_amount
      )

      @invoice.update!(used_discount_code: true)
      code.increment!(:used_count)

      # Recalculate total
      @invoice.calculate_total
    end

    redirect_to invoice_path(@invoice), notice: "Discount code '#{code.code}' applied successfully! New total: R#{@invoice.reload.total_amount.to_i}"
  rescue StandardError => e
    redirect_to invoice_path(@invoice), alert: "Error applying discount code: #{e.message}"
  end

  private

  def invoice_params
    params.require(:invoice).permit(
      :issued_date,
      :due_date,
      :subscription_id,
      invoice_items_attributes: [:id, :product_id, :quantity, :amount, :_destroy]
    )
  end

  def invoice_items_params
    # params.require(:invoice).permit(:issued_date, :due_date, :subscription_id)
    params.require(:invoice).permit(invoice_items_attributes: [ :id, :product_id, :quantity ])
  end

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def create_invoice_items(invoice)
    invoice_items_params[:invoice_items_attributes].each do |product_hash|
      if product_hash.class == Array
        product = Product.find(product_hash[1]["product_id"].to_i)
        quantity = product_hash[1]["quantity"].to_f
      else
        product = Product.find(product_hash[:product_id].to_i)
        quantity = product_hash[:quantity].to_f
      end
      next if quantity.blank? || quantity <= 0

      invoice.invoice_items.create!(
        product_id: product.id,
        quantity: quantity,
        amount: product.price
      )
    end
    invoice.calculate_total

  end
end
