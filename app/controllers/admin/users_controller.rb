# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:show, :edit, :update]

  def index
    @users = User.includes(:subscriptions).order(:first_name)
  end

  def show
    @subscriptions = @user.subscriptions
                          .includes(:collections, :invoices)
                          .order(created_at: :desc)
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

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    # Adjust according to your User model attributes
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :customer_id, :address)
  end

  def require_admin
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin?
  end
end
