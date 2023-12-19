class DriversDaysController < ApplicationController
  before_action :set_drivers_day, only: %i[drop_off end]

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
    @subscriptions = Subscription.where(collection_day: @today).order(:collection_order)
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last&.needs_bags && subscription.collections.last.needs_bags > 0}
    @new_customer = @subscriptions.select { |subscription| subscription.collections.last&.new_customer == true }
    if request.patch?
      update_drivers_day(drivers_day_params, next_path: today_subscriptions_path)
      puts "Driver's Day started at: #{current_user.drivers_day.last.start_time}"
    end
  end

  def drop_off
    raise
    @collections = @drivers_day.collections
    @total_bags_collected = @collections.sum("bags::integer")
    @total_buckets_collected = @collections.sum("buckets::integer")
    if request.patch?
      update_drivers_day(drivers_day_params, next_path: end_drivers_day_path)
    end
  end

  def end
    if request.patch?
      update_drivers_day(drivers_day_params, next_path: root_path)
      puts "Driver's Day ended at: #{current_user.drivers_day.last.end_time}"
    end
  end


  private

  def set_drivers_day
    # raise
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
    params.require(:drivers_day).permit(:start_time, :end_time, :sfl_time, :start_kms, :end_kms, :note, :total_buckets, :date)
  end
end
