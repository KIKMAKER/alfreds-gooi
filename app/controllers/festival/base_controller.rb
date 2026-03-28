class Festival::BaseController < ActionController::Base
  layout "festival"

  before_action :require_festival_access!

  helper_method :current_participant, :current_festival

  private

  def require_festival_access!
    unless session[:festival_participant_id].present?
      redirect_to new_festival_session_path, alert: "Please log in first."
    end
  end

  def current_participant
    @current_participant ||= FestivalParticipant.find_by(id: session[:festival_participant_id])
  end

  def current_festival
    @current_festival ||= current_participant&.festival_event
  end
end
