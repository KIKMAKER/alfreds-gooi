require 'csv'
class CollectionsController < ApplicationController

  def import_csv
    driver = User.find_by(role: 'driver')
    uploaded_file = params[:csv_upload][:file]
    CSV.foreach(uploaded_file.path, headers: :first_row) do |row|
      subscription = Subscription.find_by(customer_id: row['customer_id'])
      subscription.update!(collection_order: row['collection_order'])
      subscription.save
      skip = row['skip'] == 'TRUE'
      needs_bags = row['needs_bags'] == 'TRUE'
      collection = Collection.new(kiki_note: row['note'], skip: skip, needs_bags: needs_bags)
      collection.subscription = subscription
      collection.save!
      if !collection.save && skip
        puts "skip #{subscription.user.first_name}" #{subscription.user.last_name} #{subscription.user.email} #{subscription.customer_id} #{row['note']}""
      end

      # p row['NAME']gc]
    end
    redirect_to subscriptions_path, notice: 'CSV imported successfully'
  rescue CSV::MalformedCSVError => e
    redirect_to get_csv_path, alert: "Failed to import CSV: #{e.message}"
  end

  def get_csv; end

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
    if @collection && @subscription.tuesday?
      redirect_to tuesday_subscriptions_path
    elsif @collection && @subscription.wednesday?
      redirect_to wednesday_subscriptions_path
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
    # @subscription.update_pick_ups
    # redirect_to subscription_path(@subscription)
    if @collection && @subscription.tuesday?
      redirect_to tuesday_subscriptions_path
    elsif @collection && @subscription.wednesday?
      redirect_to wednesday_subscriptions_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def collection_params
    params.require(:collection).permit(:date, :time, :note, :bucket_quantity, :bucket_type)
  end
end
