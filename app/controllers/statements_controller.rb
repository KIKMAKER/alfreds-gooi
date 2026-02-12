class StatementsController < ApplicationController
  before_action :set_user, only: [:show, :send_email]
  before_action :authorize_admin_or_owner, only: [:show, :send_email]

  def show
    @invoices = @user.invoices
                     .includes(subscription: :user)
                     .order(issued_date: :desc)

    # Calculate totals
    @total_invoiced = @invoices.sum(:total_amount)
    @total_paid = @invoices.where(paid: true).sum(:total_amount)
    @balance_owing = @total_invoiced - @total_paid
  end

  def send_email
    unless current_user.admin?
      redirect_to statement_path(@user), alert: "Only admins can send statements"
      return
    end

    begin
      StatementMailer.with(user: @user).statement_created.deliver_now
      redirect_to statement_path(@user), notice: "Statement email sent successfully to #{@user.email}"
    rescue StandardError => e
      redirect_to statement_path(@user), alert: "Error sending statement: #{e.message}"
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_admin_or_owner
    unless current_user.admin? || current_user == @user
      redirect_to root_path, alert: "Not authorized"
    end
  end
end
