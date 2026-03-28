class Festival::BaseController < ActionController::Base
  layout "festival"

  # Bring in Devise helpers so we can check current_user / admin status
  include Devise::Controllers::Helpers

  before_action :require_festival_access!

  helper_method :current_participant, :current_festival, :admin_in_field?

  private

  def require_festival_access!
    # Devise admins can enter the field interface directly — no PIN needed.
    # They must have selected a festival first (via admin enter_as_logger action).
    if admin_in_field?
      unless session[:festival_event_id].present?
        redirect_to admin_festival_events_path, alert: "Select a festival to log for."
      end
      return
    end

    unless session[:festival_participant_id].present?
      redirect_to new_festival_session_path, alert: "Please log in first."
    end
  end

  def admin_in_field?
    user_signed_in? && current_user.admin?
  end

  def current_participant
    @current_participant ||= FestivalParticipant.find_by(id: session[:festival_participant_id])
  end

  def current_festival
    @current_festival ||= if session[:festival_participant_id].present?
      current_participant&.festival_event
    elsif session[:festival_event_id].present?
      FestivalEvent.find_by(id: session[:festival_event_id])
    end
  end
end
