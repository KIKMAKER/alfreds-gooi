class Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user

  def create
    @payment = @user.payments.build(payment_params)
    @payment.manual = true
    @payment.total_amount = (params[:payment][:amount_rands].to_f * 100).round

    if @payment.save
      redirect_to admin_user_path(@user), notice: "Payment of R#{params[:payment][:amount_rands]} logged."
    else
      redirect_to admin_user_path(@user), alert: "Could not log payment: #{@payment.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    payment = @user.payments.find(params[:id])
    if payment.manual?
      payment.destroy
      redirect_to admin_user_path(@user), notice: "Manual payment deleted."
    else
      redirect_to admin_user_path(@user), alert: "Only manual payments can be deleted here."
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def payment_params
    params.require(:payment).permit(:date, :payment_type, :note, :invoice_id)
  end

  def require_admin
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin?
  end
end
