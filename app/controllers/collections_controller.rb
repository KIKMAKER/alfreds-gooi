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
      @drivers_day = process_drivers_day(row, driver)
      # Process the subscription
      subscription = process_subscription(row)
      puts subscription.collection_day
      # Process the collection
      process_collection(row, subscription, @drivers_day) if subscription
    end
    @drivers_day.update!(note: params[:csv_upload][:drivers_note])
    redirect_to subscriptions_path, notice: 'CSV imported successfully'
  rescue CSV::MalformedCSVError => e
    redirect_to get_csv_path, alert: "Failed to import CSV: #{e.message}"
  end
  # the form to get the csv (no data needs to be sent from the controller)
  # the method just tells rails which view to render
  def load_csv; end

  def export_csv
    send_data Collection.to_csv, filename: "collections-#{Date.today}.csv"
  end

  # Regular CRUD stuff
  def index
    # in testing I want to be able to test the view for a given day
    # today = "Wednesday"
    # PRODUCTION
    today = Date.today
    # DEVELOPMENT
    # today = (Date.today + 1)
    @today = today.strftime("%A")
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
    @subscription = Subscription.find(params[:subscription_id])
    @collection = Collection.new(collection_params)
    @collection.subscription = @subscription
    @collection.drivers_day = DriversDay.find_or_create_by(date: @collection.date)
    if @collection.save
      redirect_to today_subscriptions_path
    else
      # puts errors.full_messages
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

  def destroy
    @collection = Collection.find(params[:id])
    @collection.destroy
    redirect_to subscription_path(@collection.subscription), notice: 'Collection was successfully deleted.'
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

    if subscription.update!(collection_day: collection_day,
                            collection_order: collection_order)
      puts "Subscription updated for #{subscription.user.first_name}"
    else
      puts "Failed to update subscription for #{subscription.user.first_name}: #{subscription.errors.full_messages.join(", ")}"
    end
    puts subscription.collection_day
    subscription
  end

  def process_collection(row, subscription, drivers_day)
    date = row['date'].present? ? DateTime.parse(row['date']) : nil
    puts date
    collection = Collection.new(
      kiki_note: row['note'], skip: row['skip'] == 'TRUE', new_customer: row['new_customer'] == 'TRUE',
      needs_bags: row['needs_bags'].to_i, date: date)
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
    params.require(:collection).permit(:alfred_message, :bags, :is_done, :skip, :date, :kiki_note, :new_customer, :buckets)
    # buckets
  end
end
