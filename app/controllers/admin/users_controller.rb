# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:show, :edit, :update, :renew_last_subscription]

  def index
    @users = User.includes(:subscriptions).order(:first_name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_create_params)
    @user.password = "password" # Generate random password

    if @user.save
      redirect_to admin_drop_off_sites_path, notice: "Drop-off manager created! They can reset their password via email."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @subscriptions = @user.subscriptions
                          .includes(:collections, :invoices)
                          .order(start_date: :desc)

    # Calculate lifetime environmental impact stats
    @lifetime_litres = @user.lifetime_litres.round(0)
    @lifetime_compost_kg = @user.lifetime_compost_kg
    @lifetime_co2e_kg = @user.lifetime_co2e_kg
  end

  def edit

  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "User updated."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def renew_last_subscription
    result = Subscriptions::RenewalService.new(user: @user).call

    if result.success?
      # Create invoice for the new subscription
      invoice = InvoiceBuilder.new(
        subscription: result.subscription,
        og: @user.og || false,
        is_new: false
      ).call

      redirect_to admin_user_path(@user),
        notice: "Created subscription ##{result.subscription.id} and invoice ##{invoice.id}."
    else
      redirect_to admin_user_path(@user),
        alert: "Could not renew subscription: #{result.error}"
    end
  rescue StandardError => e
    redirect_to admin_user_path(@user),
      alert: "Error creating subscription/invoice: #{e.message}"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    # Adjust according to your User model attributes
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :customer_id, :address)
  end

  def user_create_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :role)
  end

  def require_admin
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin?
  end
end
