class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!

  def index
    NudgePendingSubscriptionsJob.perform_later

    @active_subs           = Subscription.where(status: :active).count
    @paused_subs           = Subscription.where(status: :pause).count
    @pending_subs          = Subscription.where(status: :pending).count
    @overdue_pending_count = Subscription.pending
                                         .joins(:invoices)
                                         .where(invoices: { paid: false })
                                         .where("invoices.issued_date < ?", 7.days.ago)
                                         .distinct
                                         .count
    @collections_this_week = Collection.where(date: Date.today.all_week).count
    @draft_quotes          = Quotation.where(status: :draft).count
    @pending_referrals     = Referral.where(status: :pending).count
    @pending_inquiries     = CommercialInquiry.where(status: :pending).count

    hour = Time.now.hour
    @greeting = if hour < 12 then "Good morning"
                elsif hour < 17 then "Good afternoon"
                else "Good evening"
                end
  end

  private

  def authenticate_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorised."
    end
  end
end
