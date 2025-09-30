class DriversDaysController < ApplicationController
  before_action :set_drivers_day, only: %i[drop_off edit update destroy collections]

  def route
    selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today

    @drivers_day = DriversDay.find_or_create_by!(date: selected_date, user_id: User.find_by(first_name: "Alfred").id)
    @collections = @drivers_day.collections
                                .includes(:subscription, :user)
                                .joins(:subscription)
                                .order('subscriptions.collection_order')
                                .each_with_index do |collection, index|
                                  collection.update(position: index + 1) # Set position starting from 1
                                end
  end


  def vamos
    # in production today will be the current day,
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # today = Date.today  + 1
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_by(date: today)
    if @drivers_day
      @collections = @drivers_day.collections
      @skip_collections = @collections.where(skip: true)
      @new_customers = @collections.select { |collection| collection.new_customer == true }
      @count = @collections.count - @skip_collections.count - (@new_customers.any? ? @new_customers.count : 0)
      # @subscriptions = Subscription.active_subs_for(@today)
      # @count_skip_subscriptions = Subscription.count_skip_subs_for(@today)
      # @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
      @bags_needed = @collections.select { |collection| collection.needs_bags }

      @hours_worked = @drivers_day.hours_worked unless @drivers_day.end_time.nil?
    else
      @collections = []
      @new_customers = []
      @count = 0
      @bags_needed = []
    end
  end


  def start
    # in production today will be the current day,
    # today = "Wednesday"
    # PRODUCTION
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = (Date.today + 1)
    @today = today.strftime("%A")
    # ##
    @drivers_day = DriversDay.find_or_create_by(date: today)
    @drivers_day.start_time = Time.now
    @drivers_day.save!
    @subscriptions = Subscription.where(collection_day: @today, status: 'active').order(:collection_order)
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last&.needs_bags && subscription.collections.last.needs_bags > 0}
    @total_bags_needed = @bags_needed.sum { |subscription| subscription.collections.last.needs_bags }
    @new_customer = @subscriptions.select { |subscription| subscription.collections.last&.new_customer == true }
    if request.patch?
      if update_drivers_day(drivers_day_params, next_path: today_subscriptions_path)
        # puts "Driver's Day started at: #{current_user.drivers_days.last.start_time}"
        flash[:notice] = "Day started successfully"
      else
        flash.now[:alert] = "Failed to start the Day"
        render :start
      end
    end
  end

  # def drop_off
  #   @collections = @drivers_day.collections
  #   @total_bags_collected = @collections.sum(:bags)
  #   @total_buckets_collected = @collections.sum(:buckets)
  #   if request.patch?
  #     if update_drivers_day(drivers_day_params, next_path: end_drivers_day_path)
  #       puts "Driver's Day had #{@drivers_day.total_buckets} buckets and dropped off at #{@drivers_day.sfl_time}"
  #       flash[:notice] = "Drop off updated successfully with #{@drivers_day.total_buckets} buckets."
  #     else
  #       flash.now[:alert] = "Failed to update Driver's Day"
  #       render :drop_off
  #     end
  #   end
  # end

  def end
    @drivers_day = DriversDay.includes(:collections).find(params[:id])
    @drivers_day.end_time = Time.now
    @drivers_day.save!
    buckets       = @drivers_day.buckets
    net_kg        = buckets.sum(:weight_kg).to_f
    bucket_count  = buckets.count
    half_count    = buckets.where(half: true).count
    full_count    = bucket_count - half_count
    full_equiv    = full_count + (half_count * 0.5)

    households    = @drivers_day.collections.where(skip: false).where.not(updated_at: nil).count
    bags_sum      = @drivers_day.collections.where(skip: false).sum(:bags)

    route_hours   = if @drivers_day.start_time && @drivers_day.end_time
                      ((@drivers_day.end_time - @drivers_day.start_time) / 3600.0)
                    end
    stops_per_hr  = route_hours&.positive? ? (households / route_hours) : nil
    kg_per_hr     = route_hours&.positive? ? (net_kg / route_hours) : nil

    kms           = if @drivers_day.start_kms && @drivers_day.end_kms
                      @drivers_day.end_kms - @drivers_day.start_kms
                    end
    kg_per_km     = (kms && kms > 0) ? (net_kg / kms) : nil

    @stats = {
      net_kg:          net_kg,
      bucket_count:    bucket_count,
      full_count:      full_count,
      half_count:      half_count,
      full_equiv:      full_equiv,
      avg_kg_bucket:   bucket_count.positive? ? (net_kg / bucket_count) : 0.0,
      avg_kg_full:     full_equiv.positive? ? (net_kg / full_equiv) : 0.0,
      households:      households,
      bags_sum:        bags_sum,
      route_hours:     route_hours,
      stops_per_hr:    stops_per_hr,
      kg_per_hr:       kg_per_hr,
      kms:             kms,
      kg_per_km:       kg_per_km
    }

    return unless request.patch?

    if update_drivers_day(drivers_day_params, next_path: vamos_drivers_day_path(@drivers_day))
      CreateCollectionsJob.perform_now
      CheckSubscriptionsForCompletionJob.perform_now
      puts "Driver's Day ended at: #{@drivers_day.end_time}"
      flash[:notice] = "Day ended successfully with #{@drivers_day.end_kms} kms on the bakkie."
    else
      flash.now[:alert] = "Failed to end the Day"
      render :end
    end
  end

  def missing_customers
    @drivers_day = DriversDay.find(params[:id])
    @today = @drivers_day.date
    # Get all subscriptions for today that do not already have a collection
    existing_ids = @drivers_day.collections.pluck(:subscription_id)

    @missing_subs = Subscription
                    .where(collection_day: @today.wday)
                    .where.not(id: existing_ids)
                    .where(end_date: 1.month.ago.to_date..@today)
                    .where.not(status: "legacy")
                    .includes(:user)
  end

  def create_missing_collection
    @drivers_day = DriversDay.find(params[:id])
    subscription = Subscription.find(params[:subscription_id])

    collection = Collection.create!(
      subscription: subscription,
      drivers_day: @drivers_day,
      date: @drivers_day.date,
      bags: 0,
      skip: false,
      new_customer: false,
      buckets: 0.0
    )

    redirect_to whatsapp_message_drivers_day_path(@drivers_day, user_id: subscription.user_id)
  end

  def whatsapp_message
    @drivers_day = DriversDay.find(params[:id])
    @user = User.find(params[:user_id])
    @subscription = @user.subscriptions.order(created_at: :desc).first

    @message = <<~MSG.strip
      Hello #{@user.first_name}! You weren't on my list today because you haven't renewed your subscription yet, but I am collecting your gooi bag anyway!
      Please resubscribe before next week so that you will be on my list then :)
      You can log in to alfred.gooi.me/manage with email #{@user.email} and your password should be 'password' unless you have changed it.
    MSG

    @whatsapp_url = @user.generate_whatsapp_link(@message)
  end

  def collections
    date = @drivers_day.date
    @collections = @drivers_day.collections.includes(:subscription).where(date: date).order(date: :desc)
  end

  def index
    # fetch all instances of drivers day with necessary data with .includes
    @drivers_days = DriversDay.all.order(date: :desc)
  end

  def show
    @drivers_day = DriversDay.find(params[:id])
    @collections = @drivers_day.collections
  end

  def edit; end

  def update
    if @drivers_day.update(drivers_day_params)
      redirect_to root_path, notice: 'Driver\'s day was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @drivers_day.collections.update_all(drivers_day_id: nil)

    @drivers_day.destroy
    redirect_to drivers_days_path, note: "Drivers Day deleted"
  end

  private

  def set_drivers_day
    @drivers_day = DriversDay.find(params[:id])
  end

  def update_drivers_day(params, next_path:)
    if @drivers_day.update(params)
      redirect_to next_path
    else
      render :edit # or the appropriate view for re-editing
    end
  end

  def drivers_day_params
    params.require(:drivers_day).permit(:start_time, :end_time, :sfl_time, :start_kms, :end_kms, :note, :total_buckets, :date, :message_from_alfred, :note)
  end
end
