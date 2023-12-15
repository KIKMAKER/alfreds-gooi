class DriversDaysController < ApplicationController
  before_action :set_drivers_day, only: [:drop_off, :end]

  def start
    # in production today will be the current day,
    today = (Date.today + 4)
    # but in testing I want to be able to test the view for a given day
    # today = "Wednesday"
    @drivers_day = DriversDay.find_or_create_by(date: today)
    @subscriptions = Subscription.where(collection_day: today.day).order(:collection_order)
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last&.needs_bags }
    if request.patch?
      update_drivers_day(drivers_day_params, next_path: today_subscriptions_path)
    end
  end

  def drop_off
    if request.patch?
      update_drivers_day(drivers_day_params, next_path: end_drivers_days_path)
    end
  end

  def end
    if request
      update_drivers_day(drivers_day_params, next_path: root_path)
    end
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
    params.require(:drivers_day).permit(:start_time, :end_time, :start_kms, :end_kms, :note, :total_buckets, :date)
  end
end
