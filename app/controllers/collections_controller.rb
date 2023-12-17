require 'csv'
class CollectionsController < ApplicationController

  # I have basically all the CRUD actions, but I'm only using edit and update (the U in CRUD)
  # Creat - done by the import method and not really needing to Read or Destroy collections
  def import_csv
    # find the driver (there is only one)
    driver = User.find_by(role: 'driver')
    # get the file from the form
    uploaded_file = params[:csv_upload][:file]
    # loop through the file and create collections for each row
    CSV.foreach(uploaded_file.path, headers: :first_row) do |row|
      # Process the driver's day
      drivers_day = process_drivers_day(row, driver)
      # Process the subscription
      subscription = process_subscription(row)
      puts subscription
      # Process the collection
      process_collection(row, subscription, drivers_day) if subscription
    end
    redirect_to subscriptions_path, notice: 'CSV imported successfully'
  rescue CSV::MalformedCSVError => e
    redirect_to get_csv_path, alert: "Failed to import CSV: #{e.message}"
  end
  # the form to get the csv (no data needs to be sent from the controller)
  # the method just tells rails which view to render
  def get_csv; end

  # Regular CRUD stuff
  def index
    today = (Date.today + 3)
    @today = today.strftime("%A")
    # but in testing I want to be able to test the view for a given day
    # today = "Wednesday"
    @drivers_day = DriversDay.find_or_create_by(date: today)
    @collections = @drivers_day.collections
    # @collections = Collection.where(date: today)
  end

  def show
    @collection = Collection.find(params[:id])
  end

  def new
    @collection = Collection.new
    @subscription = Subscription.find(params[:subscription_id])
    # render partial: "collections/new", locals: { subscription: @subscription, collection: @collection}
  end

  def create
    date = Date.current + 1
    @subscription = Subscription.find(params[:subscription_id])
    @collection = Collection.new(collection_params)
    @collection.subscription = @subscription
    @collection.date = date
    driver = User.find_by(role: 'driver')
    drivers_day = driver.drivers_day.last
    @collection.drivers_day = drivers_day
    if @collection.save
      redirect_to today_subscriptions_path
    else
      puts errors.full_messages
      render :new, status: :unprocessable_entity
    end
  end
  def edit
    @collection = Collection.find(params[:id])
    @subscription = @collection.subscription
  end
  def update
    @collection = Collection.find(params[:id])
    @collection.update(collection_params)
    @subscription = @collection.subscription
    if @collection.save
      redirect_to today_subscriptions_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def process_drivers_day(row, driver)
    date = row['date'].present? ? DateTime.parse(row['date']) : nil
    drivers_day = DriversDay.find_or_create_by(date: date)
    drivers_day.user = driver
    drivers_day.save
    puts "Driver's Day processed for: #{driver.first_name}"
    drivers_day
  end

  def process_subscription(row)
    subscription = Subscription.find_by(customer_id: row['customer_id'])
    if subscription
      update_subscription(subscription, row)
    else
      puts "Subscription not found for customer_id: #{row['customer_id']}"
      nil
    end
  end

  def update_subscription(subscription, row)
    holiday_start = row['holiday_start'].present? ? DateTime.parse(row['holiday_start']) : nil
    holiday_end = row['holiday_end'].present? ? DateTime.parse(row['holiday_end']) : nil
    collection_day = row['collection_day'].to_i
    collection_order = row['collection_order'].to_i

    if subscription.update(collection_day: collection_day, collection_order: collection_order, holiday_start: holiday_start, holiday_end: holiday_end)
      puts "Subscription updated for #{subscription.user.first_name}"
    else
      puts "Failed to update subscription for #{subscription.user.first_name}: #{subscription.errors.full_messages.join(", ")}"
    end
    subscription
  end

  def process_collection(row, subscription, drivers_day)
    date = row['date'].present? ? DateTime.parse(row['date']) : nil
    puts date
    collection = Collection.new(kiki_note: row['note'], skip: row['skip'] == 'TRUE', needs_bags: row['needs_bags'].to_i, date: date)
    collection.subscription = subscription
    collection.drivers_day = drivers_day

    if collection.save
      puts "Collection created for #{subscription.user.first_name}"
    else
      puts "Failed to create collection for #{subscription.user.first_name}: #{collection.errors.full_messages.join(", ")}"
    end
  end

  # sanitise the parameters that come through from the form (strong params)
  def collection_params
    params.require(:collection).permit(:alfred_message, :bags, :is_done)
  end
end
