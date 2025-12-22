class QuotationsController < ApplicationController
  before_action :set_quotation, only: %i[show edit update destroy]
  before_action :authenticate_admin!, only: %i[index new create edit update destroy]

  def index
    @quotations = Quotation.includes(:user, :products).order(created_at: :desc)
  end

  def new
    @quotation = Quotation.new
    @quotation.created_date = Date.today
    @quotation.expires_at = Date.today + 30.days  # Default 30 day expiration
    @quotation.quotation_items.build
    @products = Product.all.order(:title)
    @users = User.where(role: :customer).order(:first_name, :last_name)
  end

  def create
    @quotation = Quotation.new(quotation_params)

    if @quotation.save
      create_quotation_items(@quotation)
      @quotation.calculate_total
      redirect_to quotation_path(@quotation), notice: 'Quotation was successfully created.'
    else
      @products = Product.all.order(:title)
      @users = User.where(role: :customer).order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @quotation = Quotation.find(params[:id])
  end

  def edit
    @products = Product.all.order(:title)
    @users = User.where(role: :customer).order(:first_name, :last_name)
    @quotation.quotation_items.build if @quotation.quotation_items.empty?
  end

  def update
    if params[:quotation][:quotation_items_attributes].present?
      # Handle updates and deletions via nested attributes
      @quotation.update(quotation_params)

      # Handle new items manually (same pattern as invoices)
      params[:quotation][:quotation_items_attributes].each do |key, item_params|
        next unless key.to_s.start_with?('new_')
        next if item_params[:quantity].blank? || item_params[:quantity].to_f <= 0

        product = Product.find(item_params[:product_id])
        @quotation.quotation_items.create!(
          product_id: product.id,
          quantity: item_params[:quantity].to_f,
          amount: product.price
        )
      end

      @quotation.calculate_total
      redirect_to quotation_path(@quotation), notice: 'Quotation was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quotation.destroy
    redirect_to quotations_path, notice: 'Quotation was successfully deleted.'
  end

  private

  def set_quotation
    @quotation = Quotation.find(params[:id])
  end

  def quotation_params
    params.require(:quotation).permit(
      :user_id,
      :subscription_id,
      :prospect_name,
      :prospect_email,
      :prospect_phone,
      :prospect_company,
      :notes,
      :created_date,
      :expires_at,
      :status,
      quotation_items_attributes: [:id, :product_id, :quantity, :amount, :_destroy]
    )
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
        amount: product.price  # Denormalize price at creation time
      )
    end
  end

  def authenticate_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You must be an admin to access this page."
    end
  end
end
