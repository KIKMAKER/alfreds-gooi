class Admin::ReferralsController < Admin::BaseController
  before_action :authenticate_user!

  def index
    @referrals = Referral.includes(:referrer, :referee, :subscription)
                         .order(created_at: :desc)
    @by_status = @referrals.group_by(&:status)
    @total     = @referrals.count
    @completed = @referrals.where(status: :completed).count
    @pending   = @referrals.where(status: :pending).count
  end
end
