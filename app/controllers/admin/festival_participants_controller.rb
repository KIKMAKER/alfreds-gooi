class Admin::FestivalParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!
  before_action :set_festival

  def new
    @participant = @festival_event.festival_participants.build
  end

  def create
    @participant = @festival_event.festival_participants.build(participant_params)
    if @participant.save
      redirect_to admin_festival_event_path(@festival_event), notice: "#{@participant.name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @participant = @festival_event.festival_participants.find(params[:id])
    @participant.destroy
    redirect_to admin_festival_event_path(@festival_event), notice: "Participant removed."
  end

  private

  def set_festival
    @festival_event = FestivalEvent.find(params[:festival_event_id])
  end

  def participant_params
    params.require(:festival_participant).permit(:name, :pin)
  end

  def authenticate_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorised."
    end
  end
end
