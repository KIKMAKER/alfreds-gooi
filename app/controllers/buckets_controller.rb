# app/controllers/buckets_controller.rb
class BucketsController < ApplicationController
  before_action :set_drivers_day
  before_action :authorize_driver!

  def index
    @buckets = @drivers_day.buckets.order(created_at: :desc)
    @bucket  = @drivers_day.buckets.build
    @totals = {
      total_buckets: @drivers_day.total_buckets.to_i,
      total_net_kg:  (@drivers_day.total_net_kg || 0).to_f,
      full_equiv:    @drivers_day.full_equivalent_count,
      avg_per_bucket: @drivers_day.avg_net_kg_per_bucket,
      avg_per_full:   @drivers_day.avg_net_kg_per_full_equiv
    }
    @completed_counts = @drivers_day.collections.where(skip: false)
                                 .where.not(updated_at: nil)
                                 .group(:drivers_day_id).count
  end

  def create
    @bucket = @drivers_day.buckets.build(bucket_params)
    if @bucket.save
      redirect_to drivers_day_buckets_path(@drivers_day), notice: "Bucket recorded."
    else
      @buckets = @drivers_day.buckets.order(created_at: :desc)
      flash.now[:alert] = @bucket.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @bucket = @drivers_day.buckets.find(params[:id])
    @bucket.destroy
    redirect_to drivers_day_buckets_path(@drivers_day), notice: "Bucket deleted."
  end

  private

  def set_drivers_day
    @drivers_day = DriversDay.find(params[:drivers_day_id])
  end

  # Make sure only the driver who owns this day (or an admin) can record buckets
  def authorize_driver!
    return if current_user&.admin? || @drivers_day.user_id == current_user&.id
    head :forbidden
  end

  def bucket_params
    params.require(:bucket).permit(:gross_kg, :half, :bucket_size)
  end
end
