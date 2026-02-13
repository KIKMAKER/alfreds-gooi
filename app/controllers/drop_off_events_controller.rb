class DropOffEventsController < ApplicationController
  before_action :set_drivers_day
  before_action :set_drop_off_event, only: [:show, :edit, :update, :complete, :record_arrival, :record_departure, :set_current_drop_off]

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

  # POST /drivers_days/:drivers_day_id/drop_off_events/:id/record_arrival
  def record_arrival
    if @drop_off_event.update(arrival_time: Time.current)
      @drivers_day.set_current_drop_off(@drop_off_event)
      render json: {
        success: true,
        arrival_time: @drop_off_event.arrival_time.iso8601,
        message: "Arrival recorded at #{@drop_off_event.drop_off_site.name}"
      }
    else
      render json: { success: false, error: @drop_off_event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /drivers_days/:drivers_day_id/drop_off_events/:id/record_departure
  def record_departure
    if @drop_off_event.update(departure_time: Time.current)
      @drivers_day.set_current_drop_off(nil) # Clear current drop-off
      render json: {
        success: true,
        departure_time: @drop_off_event.departure_time.iso8601,
        duration_minutes: @drop_off_event.duration_minutes,
        message: "Departure recorded. Duration: #{@drop_off_event.duration_display}"
      }
    else
      render json: { success: false, error: @drop_off_event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /drivers_days/:drivers_day_id/set_current_drop_off/:id
  def set_current_drop_off
    @drivers_day.set_current_drop_off(@drop_off_event)

    render json: {
      success: true,
      drop_off_event: {
        id: @drop_off_event.id,
        name: @drop_off_event.drop_off_site.name,
        has_arrival: @drop_off_event.arrival_time.present?,
        has_departure: @drop_off_event.departure_time.present?,
        arrival_time: @drop_off_event.arrival_time&.iso8601
      }
    }
  end

  private

  def set_drivers_day
    @drivers_day = DriversDay.find(params[:drivers_day_id])
  end

  def set_drop_off_event
    @drop_off_event = @drivers_day.drop_off_events.find(params[:id])
  end

  def drop_off_event_params
    params.require(:drop_off_event).permit(:driver_note, :position, :arrival_time, :departure_time, :duration_minutes, :is_final_destination)
  end
end
