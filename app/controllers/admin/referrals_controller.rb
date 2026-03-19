class Admin::ReferralsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!

  def index
    @referrals = Referral.includes(:referrer, :referee, :subscription)
                         .order(created_at: :desc)
    @by_status = @referrals.group_by(&:status)
    @total     = @referrals.count
    @completed = @referrals.where(status: :completed).count
    @pending   = @referrals.where(status: :pending).count
  end

  private

  def authenticate_admin!
    redirect_to root_path, alert: "Not authorised." unless current_user&.admin?
  end
end
