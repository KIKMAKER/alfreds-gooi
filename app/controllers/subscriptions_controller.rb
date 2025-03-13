class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: %i[show edit update destroy want_bags pause unpause holiday_dates clear_holiday complete reassign_collections welcome welcome_invoice]
  # pretty much standard CRUD stuff
  def index
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.includes(:user, :invoices)  # Preloads users to avoid N+1 queries
      .order_by_user_name

    else
      @subscriptions = Subscription.where(user_id: current_user.id)
    end
  end

  def pending
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.pending
                             .includes(:user, :invoices)  # Preloads users to avoid N+1 queries
                             .order_by_user_name
    else
      @subscriptions = Subscription.pending
                              .where(user_id: current_user.id)
    end
  end

  def active
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.active
                             .includes(:user, :invoices)  # Preloads users to avoid N+1 queries
                             .order_by_user_name
    else
      @subscriptions = Subscription.active
                              .where(user_id: current_user.id)
    end
  end

  def completed
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.completed
                             .includes(:user, :invoices)  # Preloads users to avoid N+1 queries
                             .order_by_user_name
    else
      @subscriptions = Subscription.completed
                              .where(user_id: current_user.id)
    end
  end

  def legacy
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.legacy
                             .includes(:user, :invoices)  # Preloads users to avoid N+1 queries
                             .order_by_user_name
    else
      @subscriptions = Subscription.legacy
                              .where(user_id: current_user.id)
    end
  end

  def paused
    if current_user.admin? || current_user.driver?
      @subscriptions = Subscription.paused
                             .includes(:user, :invoices)  # Preloads users to avoid N+1 queries
                             .order_by_user_name
    else
      @subscriptions = Subscription.paused
                              .where(user_id: current_user.id)
    end
  end

  def show
    @subscription = Subscription.find(params[:id])
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
  end

  def new
    @subscription = Subscription.new
  end

  def create
    @subscription = Subscription.new(subscription_params)
    @subscription.user = current_user
    @subscription.customer_id = current_user.subscriptions.last.customer_id
    @subscription.suburb = current_user.subscriptions.last.suburb
    @subscription.street_address = current_user.subscriptions.last.street_address
    @subscription.collection_order = current_user.subscriptions.last.collection_order
    @subscription.is_new_customer = false
    current_user.subscriptions.last.completed! if current_user.subscriptions.any?
    current_user.og = params[:og] == "true"
    current_user.save!
    if @subscription.save!
      # @invoice = create_invoice_for_subscription(@subscription, params[:og], params[:new])

      # redirect_to invoice_path(@invoice), notice: 'Subscription and invoice were successfully created.'
      redirect_to want_bags_subscription_path(@subscription)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def want_bags
    @invoice = create_invoice_for_subscription(@subscription, current_user.og, false)
    @compost_bags = Product.find_by(title: "Compost bin bags")
    @soil_bags = Product.find_by(title: "Soil for Life Compost")
  end

  def edit
    # @subscription = Subscription.find(params[:id])
  end

  def update
    # subscription = Subscription.find(params[:id])
    # user = subscription.user
    if @subscription.update(subscription_params)
      if @subscription.user == current_user
        if subscription_params[:street_address].present?
          @subscription.set_collection_day
        end

        redirect_to manage_path, notice: "Updated, your collection day is now #{@subscription.collection_day}"
      else
        redirect_to subscription_path(@subscription)
      end
    else
      render :edit, status: :unprocessable_entity
    end

  end

  def collections
    @subscription = Subscription.find(params[:id])
    @collections = @subscription.collections.order(date: :desc)
  end

  def complete
    # @subscription = Subscription.find(params[:id])
    @subscription.completed!
    if @subscription.start_date
      end_date = @subscription.start_date + @subscription.duration.months
    else
      @subscription.update(start_date: @subscription.created_at.to_date)
      end_date = @subscription.start_date + @subscription.duration.months
    end

    if @subscription.update!(end_date: end_date)
      redirect_to subscription_path(@subscription), notice: "#{@subscription.user.first_name}'s subscription marked complete"
    else
      redirect_to subscription_path(@subscription), notice: "Error marking #{@subscription.user.first_name}'s subscription complete"
    end
  end

  def reassign_collections
    subscription = Subscription.find(params[:id])
    user = subscription.user
    additional_collections = subscription.remaining_collections&.to_i.truncate * -1
    new_sub = user.duplicate_subscription_with_collections(additional_collections)
    redirect_to subscriptions_path, notice: "collections reassigned"
  end

  def welcome
    @subscription = Subscription.find(params[:id])
  end

  def welcome_invoice
    @subscription = Subscription.find(params[:id])
    new = params[:new]
    create_invoice_for_subscription(@subscription, nil, new) if @subscription.invoices.empty?
    @invoice = @subscription.invoices.first
    @invoices = current_user.invoices
  end

  def pause
    @subscription = Subscription.find(params[:id])
    next_collection = @subscription.collections.where("date >= ?", Date.today).order(:date).first
    if next_collection
      next_collection.update!(skip: true)
      redirect_to manage_path, notice: "Collection schedule updated"
    else
      redirect_to manage_path, notice: "Something went wrong, please try again or contact us for help"
    end
  end

  def unpause
    @subscription = Subscription.find_by(id: params[:id])

    if @subscription.nil?
      redirect_to manage_path, alert: "Subscription not found"
      return
    end

    next_collection = @subscription.collections.where("date >= ?", Date.today).order(:date).first

    if next_collection
      if next_collection.update!(skip: false)
        @subscription.update!(is_paused: false)
        redirect_to manage_path, notice: "Collection schedule updated successfully"
      else
        Rails.logger.error "Failed to update next collection: #{next_collection.errors.full_messages.join(', ')}"
        redirect_to manage_path, alert: "Failed to update the collection schedule. Please try again or contact support."
      end
    else
      if @subscription.update(is_paused: true)
        @subscription.update!(is_paused: false)
        redirect_to manage_path, notice: "Subscription unpaused successfully"
      else
        Rails.logger.error "Failed to unpause subscription: #{subscription.errors.full_messages.join(', ')}"
        redirect_to manage_path, alert: "Something went wrong while unpausing the subscription. Please try again or contact support."
      end
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

    driver = User.find_by(first_name: "Alfred")
    @drivers_day = DriversDay.find_or_create_by!(date: today, user_id: driver.id)

    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    # @subscriptions = Subscription.active_subs_for(@today)
    # @collections = @drivers_day.collections.includes(:subscription, :user).order(:position)

    @collections = @drivers_day.collections
                .includes(:subscription, :user)
                .joins(:subscription)
                .order('subscriptions.collection_order')
                .each_with_index do |collection, index|
                  collection.update(position: index + 1) # Set position starting from 1
                end
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

  def import_csv
    uploaded_file = params[:subscription][:file]
      # loop through the file and update subscriptions for each row
      CSV.foreach(uploaded_file.path, headers: :first_row) do |row|
        # Process the subscription
        subscription = process_subscription(row)
        puts subscription.end_date if subscription
      end
    redirect_to subscriptions_path, notice: "Subscriptions updated"
  end

  def update_end_date
  end

  def export
    @subscriptions = Subscription.all
    send_data generate_csv(@subscriptions),
            filename: "subscriptions_#{Date.today}.csv",
            type: "text/csv"
    # generate_csv(@subscriptions, "subscriptions_#{Date.today}.csv")

    # redirect_to subscriptions_path, notice: "Subscription data exported"
  end

  private

  def subscription_params
    params.require(:subscription).permit(:customer_id, :access_code, :apartment_unit_number, :street_address, :suburb, :duration, :start_date,
                  :collection_day, :plan, :status, :is_paused, :user_id, :holiday_start, :holiday_end, :collection_order,
                  user_attributes: [:id, :first_name, :last_name, :phone_number, :email])
  end

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def process_subscription(row)
    subscription = Subscription.find_by(customer_id: row['customer_id'])
    if subscription
      is_paused = row['status'] == 'paused'
      start_date = row['start_date'].present? ? DateTime.parse(row['start_date']) : nil

      if subscription.update!(is_paused: is_paused,
                              start_date: start_date)
        puts "Subscription updated for #{subscription.user.first_name}"
      else
        puts "Failed to update subscription for #{subscription.user.first_name}: #{subscription.errors.full_messages.join(", ")}"
      end
    # puts subscription.collection_day
    subscription
    else
      puts "Subscription not found for customer_id: #{row['customer_id']}"
      nil
    end
  end

  def generate_csv(subscriptions)
    CSV.generate(headers: true) do |csv|
      csv << ["customer_id", "first_name", "email", "suburb", "plan", "duration", "start_date", "end_date", "total_collections", "status"] # Headers

      subscriptions.each do |subscription|
        csv << [
          subscription.customer_id,
          subscription.user.first_name,
          subscription.user.email,
          subscription.suburb,
          subscription.plan,
          subscription.duration,
          subscription.start_date&.to_date,
          subscription.end_date,
          subscription.total_collections,
          subscription.is_paused ? "paused" : "active"
        ]
      end
    end
  end


  def create_invoice_for_subscription(subscription, og, new)
    invoice = Invoice.create!(
      subscription: subscription,
      issued_date: Time.current,
      due_date: Time.current + 2.week,
      total_amount: 0
    )

    # Add the subscription product to the invoice
    if og
      product = Product.find_by(title: "#{subscription.plan} #{subscription.duration} month OG subscription")
    else
      product = Product.find_by(title: "#{subscription.plan} #{subscription.duration} month subscription")
    end
    raise "Product not found" unless product

    if new == "true"
      starter_kit = Product.find_by(title: "#{subscription.plan} Starter Kit")
      invoice.invoice_items.create!(
        product: starter_kit,
        quantity: 1,
        amount: starter_kit.price
      )
    end

    invoice.invoice_items.create!(
      product: product,
      quantity: 1,
      amount: product.price
    )


    invoice.calculate_total
    invoice
  end
end
