class Admin::SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_driver

  def show
    @subscription = Subscription.joins(:user).find(params[:id])
    @next_subscription = @subscription.user.subscriptions.last if @subscription.completed?
    @collections = @subscription.collections
    @total_collections = @subscription.total_collections
    @skipped_collections = @subscription.skipped_collections
    @successful_collections = @total_collections - @skipped_collections
    @total_bags = @subscription.total_bags
    @total_buckets = @subscription.total_buckets
    @bags_last_month = @subscription.total_bags_last_n_months(1)
    @bags_last_three_months = @subscription.total_bags_last_n_months(3)
    @bags_last_six_months = @subscription.total_bags_last_n_months(6)
    @buckets_last_month = @subscription.total_buckets_last_n_months(1).to_i
    @buckets_last_three_months = @subscription.total_buckets_last_n_months(3).to_i
    @buckets_last_six_months = @subscription.total_buckets_last_n_months(6).to_i
    @total_litres = @subscription.total_litres
    @litres_last_month = @subscription.total_litres_last_n_months(1)
    @litres_last_three_months = @subscription.total_litres_last_n_months(3)
    @avg_litres_per_collection = @subscription.avg_litres_per_collection
    @allowed_litres = @subscription.allowed_litres_per_collection
    scope = @subscription.collections
                       .where(skip: false)
                       .where.not(updated_at: nil, time: nil)
    avg_secs = scope.where.not(time: nil)
                    .average(Arel.sql(
                      "EXTRACT(EPOCH FROM ((time AT TIME ZONE 'Africa/Johannesburg') - DATE_TRUNC('day', (time AT TIME ZONE 'Africa/Johannesburg'))))"
                    )).to_f

    @avg_time_sample     = scope.where.not(time: nil).count
    @avg_collection_time = @avg_time_sample.positive? ? (Time.zone.now.beginning_of_day + avg_secs).strftime('%H:%M') : nil
  end

  private

  def require_admin_or_driver
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin? || current_user.driver?
  end
end
