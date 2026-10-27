class Admin::FestivalWasteLogsController < Admin::BaseController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_log

  def edit
  end

  def update
    if @log.update(@log.edit_attributes_from(params))
      redirect_to dashboard_admin_festival_event_path(@festival_event), notice: "Entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @log.destroy
    redirect_to dashboard_admin_festival_event_path(@festival_event), notice: "Entry deleted."
  end

  private

  def set_festival
    @festival_event = FestivalEvent.find(params[:festival_event_id])
  end

  def set_log
    @log = @festival_event.festival_waste_logs.find(params[:id])
  end
end
