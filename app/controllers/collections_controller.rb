require 'csv'
class CollectionsController < ApplicationController
  before_action :set_collection, only: [:show, :edit, :update, :destroy, :add_bags, :remove_bags, :add_customer_note, :update_position]

  def perform_create_collections
    CreateCollectionsJob.perform_now
    flash[:notice] = "Create Collections Job has been triggered."
    redirect_to this_week_collections_path
  end

  def optimise_route
    drivers_day = DriversDay.find_by(date: Date.today)
    RouteOptimiser.optimise_route
    redirect_to start_drivers_day_path(drivers_day), notice: 'Route optimized successfully'
  end

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
      puts subscription.collection_day if subscription
      # Process the collection
      process_collection(row, subscription, @drivers_day) if subscription
    end
    @drivers_day.update!(note: params[:csv_upload][:drivers_note])
    redirect_to subscriptions_path, notice: 'CSV imported successfully'
  rescue CSV::MalformedCSVError => e
    redirect_to load_csv_collections_path, alert: "Failed to import CSV: #{e.message}"
  end
  # the form to get the csv (no data needs to be sent from the controller)
  # the method just tells rails which view to render
  def load_csv; end

  def export_csv
    send_data Collection.to_csv, filename: "collections-#{Date.today}.csv"
  end

  # Regular CRUD stuff
  def index
    @subscription = Subscription.find(params[:subscription_id])
    @collections = @subscription.collections
  end

  def show
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
    @subscription = @collection.subscription
  end

  def update
    if @collection.update!(collection_params)
      redirect_to today_subscriptions_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def skip_today
    skipped_params = 0
    skipped = 0
    params[:skip_today_collections].each do |id, collection_params|
      collection = Collection.find(id)
      skipped_params += 1 if collection_params == "1"
      if collection_params == "1" && collection.update!(skip: collection_params)
        skipped += 1
      else
        puts "Failed to skip collection #{collection.id}"
      end
    end
    flash[:notice] = "Collections updated successfully!" if skipped_params == skipped
    redirect_to this_week_collections_path
  end

  def this_week
    @day = Date.today.strftime("%A")
    @unskipped_collections = Collection.where(created_at: Date.today.all_day, date: Date.today , skip: false)
    @skipped_collections = Collection.where(created_at: Date.today.all_day, date: Date.today , skip: true)

  end

  def destroy
    @collection.destroy
    redirect_to request.referer || collections_path, notice: "Collection was successfully deleted."
  end

  def add_bags
    if @collection.needs_bags == 3
      flash[:notice] = "Maximum bags reached"
    else
      @collection.needs_bags += 1
      if @collection.save
        redirect_to manage_path
        flash[:notice] = "Added bags"
      end

    end
  end

  def remove_bags
    if @collection.needs_bags == 0
      flash[:notice] = "Minimum bags reached"
    else
      @collection.needs_bags -= 1
      if @collection.save
        redirect_to manage_path
        flash[:notice] = "Removed bags"
      end

    end
  end

  def add_customer_note
    if @collection.update(customer_note: params[:collection][:customer_note])
      redirect_to manage_path
      flash[:notice] = "Note Added!"
    end
  end

  def update_position
    @collection = Collection.find(params[:id])
    new_position = params[:position].to_i

    # Use acts_as_list to reorder
    @collection.insert_at(new_position)

    update_collection_order(@collection.drivers_day)

    head :no_content
  end

  def reset_order
    @drivers_day = DriversDay.find(params[:drivers_day_id])

    # Order by subscriptions.collection_order and update positions
    @drivers_day.collections
                .joins(:subscription)
                .order('subscriptions.collection_order')
                .each_with_index do |collection, index|
      collection.update(position: index + 1) # Set position starting from 1
    end
  end

  private

  def update_collection_order(drivers_day)
    drivers_day.collections.order(:position).each_with_index do |collection, index|
      # Update the associated subscription's collection_order
      subscription = collection.subscription
      subscription.update(collection_order: index + 1) if subscription.present?
    end
  end

  def process_drivers_day(row, driver)
    date = row['date'].present? ? DateTime.parse(row['date']) : nil
    drivers_day = DriversDay.find_or_create_by(date: date)
    drivers_day.user = driver
    drivers_day.save
    puts "Driver's Day processed for: #{driver.first_name} with id: #{drivers_day.id}"
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

  def set_collection
    @collection = Collection.find(params[:id])
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
    # puts subscription.collection_day
    subscription
  end

  def process_collection(row, subscription, drivers_day)
    date = row['date'].present? ? DateTime.parse(row['date']) : nil
    puts date
    collection = Collection.new(
      kiki_note: row['note'], skip: row['skip'] == 'TRUE', new_customer: row['new_customer'] == 'TRUE',
      needs_bags: row['needs_bags'].to_i, soil_bag: row['soil_bag'].to_i, date: date, wants_veggies: row["wants_veggies"] == 'TRUE')
    collection.subscription = subscription
    collection.drivers_day = drivers_day
    if collection.save
      puts "Collection created for #{subscription.user.first_name}"
    else
      puts "Failed to create collection for #{subscription.user.first_name}: #{collection.errors.full_messages.join(", ")}"
    end
    collection
  end

  # sanitise the parameters that come through from the form (strong params)
  def collection_params
    params.require(:collection).permit(:alfred_message, :bags, :is_done, :skip, :date, :kiki_note, :new_customer, :buckets, :time, :needs_bags, :dropped_off_buckets, :soil_bag, :wants_veggies)
    # buckets
  end
end
