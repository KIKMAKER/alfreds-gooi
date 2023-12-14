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
      drivers_day = DriversDay.find_or_create_by(date: row['date'])
      # assign the driver the the newly created drivers day
      drivers_day.user = driver
      drivers_day.save
      puts drivers_day.user.first_name
      # find the subscription for the row
      subscription = Subscription.find_by(customer_id: row['customer_id'])
      subscription.update!(collection_day: row['collection_day'].to_i, collection_order: row['collection_order'], holiday_start: row['holiday_start'], holiday_end: row['holiday_end'])
      subscription.save!
      puts subscription.user.first_name
      # values come in as strings so I convert them to boolean by comparing them to the string 'TRUE' (double = is a comparison, single = is an assignment)
      skip = row['skip'] == 'TRUE'
      puts skip
      # create the collection
      collection = Collection.new(kiki_note: row['note'], skip: skip, needs_bags: row['needs_bags'], date: row['date'])
      # assign the subscription and drivers day to the collection
      collection.subscription = subscription
      collection.drivers_day = drivers_day
      collection.save!
      puts collection.subscription.user.first_name
      # error handling for if the collection doesn't save but has SKIP as true (need to see in the server logs when I upload and then change directly)
      if !collection.save && skip
        puts "skip #{subscription.user.first_name}" #{subscription.user.last_name} #{subscription.user.email} #{subscription.customer_id} #{row['note']}""
      end
    end
    redirect_to subscriptions_path, notice: 'CSV imported successfully'
  rescue CSV::MalformedCSVError => e
    redirect_to get_csv_path, alert: "Failed to import CSV: #{e.message}"
  end

  # the form to get the csv (no data needs to be sent from the controller)
  def get_csv; end

  # Regular CRUD stuff
  def index
    @collections = Collection.all
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
    @collection.save
    if @collection.save
      redirect_to today_subscriptions_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @collection = Collection.find(params[:id])
    @subscription = @collection.subscription
  end

  def update
    @collection = Collection.find(params[:id])
    @collection.time = @collection.updated_at
    @collection.update(collection_params)
    @subscription = @collection.subscription

    if @collection.save
      redirect_to today_subscriptions_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # sanitise the parameters that come through from the form (strong params)
  def collection_params
    params.require(:collection).permit(:alfred_message, :bags)
  end
end
