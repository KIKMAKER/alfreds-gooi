require "csv"

class Admin::FestivalEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!
  before_action :set_festival, only: [:show, :edit, :update, :destroy, :dashboard, :export_csv]

  def index
    @festival_events = FestivalEvent.order(start_date: :desc)
  end

  def show
  end

  def new
    @festival_event = FestivalEvent.new
  end

  def create
    @festival_event = FestivalEvent.new(festival_event_params)
    if @festival_event.save
      redirect_to admin_festival_event_path(@festival_event), notice: "Festival created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @festival_event.update(festival_event_params)
      redirect_to admin_festival_event_path(@festival_event), notice: "Festival updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @festival_event.destroy
    redirect_to admin_festival_events_path, notice: "Festival deleted."
  end

  def dashboard
    @logs = @festival_event.festival_waste_logs.includes(:festival_participant).order(:day_number, :logged_at)

    @totals_by_category = @festival_event.festival_waste_logs
                                         .group(:category)
                                         .sum(:weight_kg)
                                         .transform_values { |v| v.to_f.round(3) }

    dest_map = FestivalWasteLog.destinations.invert
    @totals_by_destination = @festival_event.festival_waste_logs
                                            .organic
                                            .group(:destination)
                                            .sum(:weight_kg)
                                            .each_with_object({}) do |(k, v), h|
                                              h[dest_map[k]] = v.to_f.round(3) if k
                                            end

    src_map = FestivalWasteLog.sources.invert
    @totals_by_source = @festival_event.festival_waste_logs
                                       .organic
                                       .group(:source)
                                       .sum(:weight_kg)
                                       .each_with_object({}) do |(k, v), h|
                                         h[src_map[k]] = v.to_f.round(3) if k
                                       end

    @totals_by_day_category = @festival_event.festival_waste_logs
                                             .group(:day_number, :category)
                                             .sum(:weight_kg)
                                             .transform_values { |v| v.to_f.round(3) }

    @grand_total  = @festival_event.festival_waste_logs.sum(:weight_kg).to_f.round(3)
    @gooi_total   = @festival_event.festival_waste_logs.organic.sum(:weight_kg).to_f.round(3)
    @chanel_total = @festival_event.festival_waste_logs.inorganic.sum(:weight_kg).to_f.round(3)
  end

  def export_csv
    logs = @festival_event.festival_waste_logs.includes(:festival_participant).order(:day_number, :logged_at)

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Festival", "Day", "Date/Time", "Logged By", "Team", "Category", "Weight (kg)", "Notes"]
      logs.each do |log|
        csv << [
          @festival_event.name,
          log.day_number,
          log.logged_at.strftime("%Y-%m-%d %H:%M"),
          log.festival_participant&.name,
          log.team,
          log.category_label,
          log.weight_kg,
          log.notes
        ]
      end
    end

    send_data csv_data,
              filename: "#{@festival_event.name.parameterize}-waste-logs.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def set_festival
    @festival_event = FestivalEvent.find(params[:id])
  end

  def festival_event_params
    params.require(:festival_event).permit(:name, :start_date, :end_date)
  end

  def authenticate_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorised."
    end
  end
end
