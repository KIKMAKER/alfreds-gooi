class Admin::QuotationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_quotation, only: %i[edit update destroy send_email extend_expiry]

  def index
    @quotations = Quotation.includes(:user, :products).order(created_at: :desc)
  end

  def new
    @quotation = Quotation.new(quotation_prefill_params)
    @quotation.created_date = Date.today
    @quotation.expires_at   = Date.today + 30.days
    @quotation.duration_months ||= 6
    @quotation.quotation_items.build
    @products = Product.quote_eligible.order(:title)
    @users    = User.where(role: :customer).order(:first_name, :last_name)
  end

  def create
    @quotation = Quotation.new(quotation_params.except(:quotation_items_attributes))

    if @quotation.save
      create_quotation_items(@quotation)
      @quotation.calculate_total
      redirect_to quotation_path(@quotation), notice: 'Quotation was successfully created.'
    else
      @products = Product.quote_eligible.order(:title)
      @users = User.where(role: :customer).order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = Product.quote_eligible.order(:title)
    @users = User.where(role: :customer).order(:first_name, :last_name)
    @quotation.quotation_items.build if @quotation.quotation_items.empty?
  end

  def update
    @quotation.update(quotation_params)
    create_new_quotation_items(@quotation)
    @quotation.calculate_total
    redirect_to quotation_path(@quotation), notice: 'Quotation was successfully updated.'
  end

  def destroy
    @quotation.destroy
    redirect_to admin_quotations_path, notice: 'Quotation was successfully deleted.'
  end

  def send_email
    begin
      QuotationMailer.with(quotation: @quotation).quotation_created.deliver_now
      @quotation.update(status: :sent) if @quotation.status == 'draft'
      redirect_to quotation_path(@quotation), notice: "Quotation email sent successfully to #{@quotation.customer_email}"
    rescue StandardError => e
      redirect_to quotation_path(@quotation), alert: "Error sending quotation: #{e.message}"
    end
  end

  def extend_expiry
    if @quotation.accepted? || @quotation.rejected?
      return redirect_to quotation_path(@quotation), alert: "Can't extend a quotation that's already #{@quotation.status}."
    end

    new_expiry = [@quotation.expires_at, Date.today].max + 30.days
    @quotation.update!(expires_at: new_expiry, status: :sent)
    redirect_to quotation_path(@quotation), notice: "Expiry extended to #{new_expiry.strftime('%-d %b %Y')}."
  end

  private

  def set_quotation
    @quotation = Quotation.find(params[:id])
  end

  def quotation_prefill_params
    return {} unless params[:quotation].present?
    params.require(:quotation).permit(
      :prospect_name, :prospect_email, :prospect_phone,
      :prospect_company, :duration_months, :notes, :block_id
    )
  end

  def quotation_params
    params.require(:quotation).permit(
      :user_id,
      :subscription_id,
      :block_id,
      :prospect_name,
      :prospect_email,
      :prospect_phone,
      :prospect_company,
      :notes,
      :duration_months,
      :collections_per_week,
      :buckets_per_collection,
      :created_date,
      :expires_at,
      :status,
      quotation_items_attributes: [:id, :product_id, :quantity, :amount, :_destroy]
    )
  end

  def create_new_quotation_items(quotation)
    return unless params[:quotation][:quotation_items_attributes]

    params[:quotation][:quotation_items_attributes].each do |key, attrs|
      next unless key.to_s.start_with?("new_")
      quantity = attrs["quantity"].to_f
      next if quantity <= 0

      quotation.quotation_items.create!(
        product_id: attrs["product_id"].to_i,
        quantity:   quantity,
        amount:     attrs["amount"].to_f
      )
    end
  end

  def create_quotation_items(quotation)
    return unless params[:quotation][:quotation_items_attributes]

    params[:quotation][:quotation_items_attributes].each do |key, product_hash|
      if product_hash.class == Array
        product = Product.find(product_hash[1]["product_id"].to_i)
        quantity = product_hash[1]["quantity"].to_f
      else
        product = Product.find(product_hash[:product_id].to_i)
        quantity = product_hash[:quantity].to_f
      end
      next if quantity.blank? || quantity <= 0

      quotation.quotation_items.create!(
        product_id: product.id,
        quantity: quantity,
        amount: product.price
      )
    end
  end
end
