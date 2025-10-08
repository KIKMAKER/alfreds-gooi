class DropOffEventsController < ApplicationController
  before_action :set_drivers_day
  before_action :set_drop_off_event, only: [:show, :edit, :update, :complete]

  def index
    @drop_off_events = @drivers_day.drop_off_events.includes(:drop_off_site).order(:position)
  end

  def show
    @buckets = @drop_off_event.buckets.order(created_at: :desc)
  end

  def edit
  end

  def update
    if @drop_off_event.update(drop_off_event_params)
      redirect_to drivers_day_drop_off_event_path(@drivers_day, @drop_off_event), notice: "Drop-off event updated!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def complete
    @drop_off_event.update!(is_done: true, time: Time.current)
    @drop_off_event.drop_off_site.recalc_totals!
    redirect_to drivers_day_drop_off_event_path(@drivers_day, @drop_off_event), notice: "Drop-off completed!"
  end

  private

  def set_drivers_day
    @drivers_day = DriversDay.find(params[:drivers_day_id])
  end

  def set_drop_off_event
    @drop_off_event = @drivers_day.drop_off_events.find(params[:id])
  end

  def drop_off_event_params
    params.require(:drop_off_event).permit(:driver_note, :position)
  end
end
