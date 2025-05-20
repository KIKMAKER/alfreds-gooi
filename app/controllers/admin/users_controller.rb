# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:edit, :update]

  def index
    @users = User.order(:created_at)
  end

  def edit

  end

  def update
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "User updated successfully."
    else
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
