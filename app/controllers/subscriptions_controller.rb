class SubscriptionsController < ApplicationController
  # pretty much standard CRUD stuff
  def index
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.all
    else
      @subscriptions = Subscription.where(user_id: current_user.id)
    end
  end

  def show
    @subscription = Subscription.find(params[:id])
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
  end

  def new
    @subscription = Subscription.new
  end

  def create
    @subscription = Subscription.new(subscription_params)
    @subscription.user = current_user
    if @subscription.save
      @invoice = create_invoice_for_subscription(@subscription)
      redirect_to invoice_path(@invoice), notice: 'Subscription and invoice were successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @subscription = Subscription.find(params[:id])
  end

  def update
    subscription = Subscription.find(params[:id])
    # user = subscription.user

    if subscription.update(subscription_params)
      if subscription.user == current_user
        redirect_to manage_path
      else
        redirect_to subscription_path(subscription)
      end
    else
      render :edit, status: :unprocessable_entity
    end

  end

  def welcome_invoice
    @subscription = Subscription.find(params[:id])

    @subscription.create_initial_invoice if @subscription.invoices.empty?
    @invoice = @subscription.invoices.first
    @invoices = current_user.invoices
  end

  def pause
    @subscription = Subscription.find(params[:id])
    if @subscription.update(is_paused: true)
      redirect_to manage_path, notice: "Collection schedule updated"
    else
      redirect_to manage_path, notice: "Something went wrong, please try again or contact us for help"
    end
  end

  def unpause
    @subscription = Subscription.find(params[:id])
    if @subscription.update(is_paused: false)
      redirect_to manage_path, notice: "Collection schedule updated"
    else
      redirect_to manage_path, notice: "Something went wrong, please try again or contact us for help"
    end
  end

  def holiday_dates
    @subscription = Subscription.find(params[:id])
    if @subscription.update(subscription_params)
      redirect_to manage_path, notice: "Holiday set!"
    else
      redirect_to manage_path, status: :unprocessable_entity
    end
  end

  # set holiday start and end to nil to clear holiday
  def clear_holiday
    @subscription = Subscription.find(params[:id])
    if @subscription.update(holiday_start: nil, holiday_end: nil)
      redirect_to manage_path, notice: "Holiday Canceled!"
    else
      redirect_to manage_path, status: :unprocessable_entity
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
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    # @subscriptions = Subscription.active_subs_for(@today)
    # @collections = @drivers_day.collections.includes(:subscription, :user).order(:order)
    @collections = @drivers_day.collections
                              .includes(:subscription, :user)
                              .joins(:subscription)
                              .order('subscriptions.collection_order ASC')
  end

  def tomorrow
     # in production today will be the current day,
    # today = "Wednesday"
    # PRODUCTION
    tomorrow = Date.today + 1
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = Date.today  + 2
    @tomorrow = tomorrow.strftime("%A")
    @drivers_day = DriversDay.find_or_create_by(date: tomorrow)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    @subscriptions = Subscription.active_subs_for(@tomorrow)
  end

  # a special view that will load all of the collections for a given day
  def today_notes
    # in production today will be the current day,
    # today = "Wednesday"
    # PRODUCTION
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = Date.today  + 1
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_or_create_by(date: today)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    @subscriptions = Subscription.active_subs_for(@today)
  end

  private

  def subscription_params
    params.require(:subscription).permit(:customer_id, :access_code, :street_address, :suburb, :duration, :start_date,
                  :collection_day, :plan, :is_paused, :user_id, :holiday_start, :holiday_end, :collection_order,
                  user_attributes: [:id, :first_name, :last_name, :phone_number, :email])
  end


  def create_invoice_for_subscription(subscription)
    invoice = Invoice.create!(
      subscription: subscription,
      issued_date: Time.current,
      due_date: Time.current + subscription.duration.months,
      total_amount: 0
    )

    # Add the subscription product to the invoice
    product = Product.find_by(title: "#{subscription.plan.capitalize} #{subscription.duration} month subscription")
    raise "Product not found" unless product

    invoice.invoice_items.create!(
      product: product,
      quantity: 1,
      amount: product.price
    )

    invoice.calculate_total
    invoice
  end
end

