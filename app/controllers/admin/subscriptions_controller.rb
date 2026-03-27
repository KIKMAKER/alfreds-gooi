class Admin::SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_driver

  def new
    @user = User.find(params[:user_id])
    @subscription = Subscription.new
  end

  def create
    @user = User.find(params[:user_id])
    @subscription = @user.subscriptions.build(subscription_params)
    @subscription.status   = :pending
    @subscription.is_paused = true

    if @subscription.save
      referee = User.find_by(referral_code: @subscription.referral_code) if @subscription.referral_code.present?
      InvoiceBuilder.new(
        subscription: @subscription,
        is_new:       @subscription.is_new_customer,
        referee:      referee
      ).call
      CreateFirstCollectionJob.perform_now(@subscription) if @subscription.once_off?
      redirect_to admin_user_path(@user), notice: "Subscription created and invoice sent."
    else
      render :new, status: :unprocessable_entity
    end
  end

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

  def subscription_params
    params.require(:subscription).permit(
      :plan, :duration, :start_date, :street_address, :suburb,
      :apartment_unit_number, :discount_code, :referral_code, :is_new_customer
    )
  end

  def require_admin_or_driver
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin? || current_user.driver?
  end
end
