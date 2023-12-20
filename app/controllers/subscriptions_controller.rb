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

  def update
    @subscription = Subscription.find(params[:id])
    if @subscription.update(subscription_params)
      redirect_to root_path, notice: "Subscription updated"
    else
      redirect_to root_path, status: :unprocessable_entity, notice: "There was a problem updating your subscription, please try again."

    end
  end

  # a special view that will load all of the collections for a given day
  def today
    # in production today will be the current day,
    # today = "Wednesday"
    # PRODUCTION
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = (Date.today + 1)
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_or_create_by(date: today)
    # @subscriptions = Subscription.where(collection_day: @today).order(:collection_order)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    @subscriptions = Subscription.includes(:collections)
                                .where(collection_day: @today)
                                .order(:collection_order)
    # @drivers_day = @subscriptions.last.collections.last.drivers_day
  end

  private
  def subscription_params
    params.require(:subscription).permit(:is_paused, :holiday_start, :holiday_end)
  end
end
