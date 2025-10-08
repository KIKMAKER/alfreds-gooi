class DropOffEvents::BucketsController < ApplicationController
  before_action :set_drivers_day_and_drop_off_event
  before_action :authorize_driver!

  def create
    @bucket = @drop_off_event.buckets.build(bucket_params)
    @bucket.drivers_day = @drivers_day

    if @bucket.save
      # Recalculate drop-off event weight from buckets
      @drop_off_event.update!(weight_kg: @drop_off_event.total_weight_from_buckets)
      redirect_to drivers_day_drop_off_event_path(@drivers_day, @drop_off_event), notice: "Bucket recorded."
    else
      flash[:alert] = @bucket.errors.full_messages.to_sentence
      redirect_to drivers_day_drop_off_event_path(@drivers_day, @drop_off_event)
    end
  end

  def destroy
    @bucket = @drop_off_event.buckets.find(params[:id])
    @bucket.destroy

    # Recalculate drop-off event weight from remaining buckets
    @drop_off_event.update!(weight_kg: @drop_off_event.total_weight_from_buckets)
    redirect_to drivers_day_drop_off_event_path(@drivers_day, @drop_off_event), notice: "Bucket deleted."
  end

  private

  def set_drivers_day_and_drop_off_event
    @drivers_day = DriversDay.find(params[:drivers_day_id])
    @drop_off_event = @drivers_day.drop_off_events.find(params[:drop_off_event_id])
  end

  def authorize_driver!
    return if current_user&.admin? || @drivers_day.user_id == current_user&.id
    head :forbidden
  end

  def bucket_params
    params.require(:bucket).permit(:gross_kg, :half)
  end
end
