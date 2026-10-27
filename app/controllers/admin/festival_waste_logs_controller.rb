class Admin::FestivalWasteLogsController < Admin::BaseController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_log

  def edit
  end

  def update
    attrs = @log.edit_attributes_from(params)
    target = FestivalEvent.find_by(id: params[:festival_event_id_new])
    if target && target != @festival_event
      # The logger belonged to the old festival, so the link is dropped on a move.
      attrs.merge!(festival_event: target, festival_participant: nil)
    end

    if @log.update(attrs)
      notice = target && target != @festival_event ? "Entry moved to #{target.name}." : "Entry updated."
      redirect_to dashboard_admin_festival_event_path(@log.festival_event), notice: notice
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
