class Admin::DashboardController < Admin::BaseController
  before_action :authenticate_user!

  def index
    NudgePendingSubscriptionsJob.perform_later

    @active_subs           = Subscription.where(status: :active).count
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
    @draft_posts           = Post.where(published: false).count

    interests_by_suburb    = Interest.group(:suburb).count.sort_by { |_, n| -n }
    @interests_count       = interests_by_suburb.sum(&:last)
    @top_interest_suburb   = interests_by_suburb.first&.then { |suburb, n| "#{suburb} (#{n})" }

    hour = Time.now.hour
    @greeting = if hour < 12 then "Good morning"
                elsif hour < 17 then "Good afternoon"
                else "Good evening"
                end
  end
end
