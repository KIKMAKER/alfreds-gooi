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
    @subscriptions = Subscription.where(collection_day: @today).order(:collection_order)
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last&.needs_bags && subscription.collections.last.needs_bags > 0}
    @wants_veggies = @subscriptions.select { |subscription| subscription.collections.last&.wants_veggies}
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
    @collections = @drivers_day.collections
    @total_bags_collected = @collections&.sum(:bags) || 0
    @total_bags_collected = @total_bags_collected.floor
    day_name = Date.today.strftime("%A")
    @total_buckets_collected = @collections&.sum(:buckets).floor || 0
    return unless request.patch?

    if update_drivers_day(drivers_day_params, next_path: vamos_path)
      CreateCollectionsJob.perform_now(day_name)
      puts "Driver's Day ended at: #{@drivers_day.end_time}"
      flash[:notice] = "Day ended successfully with #{@drivers_day.end_kms} kms on the bakkie."
    else
      flash.now[:alert] = "Failed to end the Day"
      render :end
    end
  end

  def collections
    date = @drivers_day.date
    @collections = @drivers_day.collections.includes(:subscription).where(date: date).order(date: :desc)
  end

  def index
    # fetch all instances of drivers day with necessary data with .includes
    @drivers_days = DriversDay.all.order(date: :asc)
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
