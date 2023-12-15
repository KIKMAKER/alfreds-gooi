class SubscriptionsController < ApplicationController
  # pretty much standard CRUD stuff
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

  # a special view that will load all of the collections for a given day
  def today
    # in production today will be the current day,
    # @today = Date.today.strftime("%A")
    # but in testing I want to be able to test the view for a given day
    @today = (Date.today + 4)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    @subscriptions = Subscription.includes(:collections)
                                .where(collection_day: @today.strftime("%A"))
                                .order(:collection_order)
    @drivers_day = @subscriptions.last.collections.last.drivers_day
  end
end
