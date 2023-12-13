class SubscriptionsController < ApplicationController
  def index
    @subscriptions = Subscription.all
  end

  def show
    @subscription = Subscription.find(params[:id])
    @collections = @subscription.collections
  end

  def new
    @subscription = Subscription.new
  end

  def today
    today = Date.today.strftime("%A")
    @subscriptions = Subscription.where(collection_day: today)
  end
end
