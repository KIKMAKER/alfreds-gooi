class Admin::BulkMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def index
    @message = params[:message]
    @users = filter_users
  end

  private

  def filter_users
    # Start with active subscriptions
    subscriptions = Subscription.active.includes(:user)

    # Filter by collection day
    if params[:collection_day].present? && params[:collection_day] != 'all'
      subscriptions = subscriptions.where(collection_day: params[:collection_day])
    end

    # Filter by suburb
    if params[:suburb].present? && params[:suburb] != 'all'
      subscriptions = subscriptions.where(suburb: params[:suburb])
    end

    # Filter by plan
    if params[:plan].present? && params[:plan] != 'all'
      subscriptions = subscriptions.where(plan: params[:plan])
    end

    # Filter by number of collections (minimum)
    if params[:min_collections].present?
      subscription_ids = subscriptions.select { |sub| sub.total_collections >= params[:min_collections].to_i }.map(&:id)
      subscriptions = Subscription.where(id: subscription_ids)
    end

    # Filter by number of collections (maximum)
    if params[:max_collections].present?
      subscription_ids = subscriptions.select { |sub| sub.total_collections <= params[:max_collections].to_i }.map(&:id)
      subscriptions = Subscription.where(id: subscription_ids)
    end

    # Filter by first subscription date (from)
    if params[:date_from].present?
      subscriptions = subscriptions.where('start_date >= ?', params[:date_from])
    end

    # Filter by first subscription date (to)
    if params[:date_to].present?
      subscriptions = subscriptions.where('start_date <= ?', params[:date_to])
    end

    # Get unique users (in case they have multiple subscriptions)
    User.where(id: subscriptions.pluck(:user_id).uniq).order(:first_name, :last_name)
  end

  def ensure_admin
    redirect_to root_path, alert: 'Not authorized' unless current_user&.admin?
  end
end
