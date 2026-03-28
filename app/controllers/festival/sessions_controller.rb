class Festival::SessionsController < ActionController::Base
  layout "festival"

  def new
    @festival_events = FestivalEvent.order(start_date: :desc)
  end

  def create
    festival = FestivalEvent.find_by(id: params[:festival_event_id])
    participant = festival&.festival_participants&.find_by(name: params[:name], pin: params[:pin])

    if participant
      session[:festival_participant_id] = participant.id
      redirect_to festival_waste_logs_path, notice: "Welcome, #{participant.name}!"
    else
      @festival_events = FestivalEvent.order(start_date: :desc)
      flash.now[:alert] = "Name or PIN not recognised. Try again."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:festival_participant_id)
    redirect_to new_festival_session_path, notice: "Logged out."
  end
end
