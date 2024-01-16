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

  def create
    @subscription = Subscription.new(subscription_params)
    @subscription.user = current_user
    if @subscription.save
      redirect_to subscription_path(@subscription)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @subscription = Subscription.find(params[:id])
  end

  def update
    @subscription = Subscription.find(params[:id])
    if @subscription.update(subscription_params)
      redirect_to subscription_path(@subscription)
    else
      render :edit, status: :unprocessable_entity
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
    # today = Date.today  + 1
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_or_create_by(date: today)
    # @subscriptions = Subscription.where(collection_day: @today).order(:collection_order)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    @subscriptions = Subscription.includes(:collections)
                                .where(collection_day: @today)
                                .order(:collection_order)
    # @drivers_day = @subscriptions.last.collections.last.drivers_day
  end

  def tomorrow
     # in production today will be the current day,
    # today = "Wednesday"
    # PRODUCTION
    tomorrow = Date.today + 1
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = Date.today  + 1
    @tomorrow = tomorrow.strftime("%A")
    @drivers_day = DriversDay.find_or_create_by(date: tomorrow)
    # @subscriptions = Subscription.where(collection_day: @today).order(:collection_order)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    @subscriptions = Subscription.includes(:collections)
                                .where(collection_day: @tomorrow)
                                .order(:collection_order)
    # @drivers_day = @subscriptions.last.collections.last.drivers_day
  end

  private
  def subscription_params
    params.require(:subscription).permit(:customer_id, :access_code, :street_address, :suburb, :duration, :start_date,
                  :collection_day, :plan, :is_paused, :user_id, :holiday_start, :holiday_end, :collection_order)
  end
end
