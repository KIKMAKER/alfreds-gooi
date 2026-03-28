class Festival::BaseController < ActionController::Base
  layout "festival"

  # Bring in Devise helpers so we can check current_user / admin status
  include Devise::Controllers::Helpers

  before_action :require_festival_access!

  helper_method :current_participant, :current_festival, :admin_in_field?

  private

  def require_festival_access!
    return if festival_participant_id.present?

    if admin_in_field?
      redirect_to admin_festival_events_path, alert: "Select a festival to log for."
    else
      redirect_to new_festival_session_path, alert: "Please log in first."
    end
  end

  def admin_in_field?
    user_signed_in? && current_user.admin?
  end

  # Checks session first (fast), falls back to permanent cookie so PWA restarts
  # on iOS don't clear the session and force re-login.
  def festival_participant_id
    session[:festival_participant_id] || cookies[:festival_participant_id]
  end

  def current_participant
    @current_participant ||= FestivalParticipant.find_by(id: festival_participant_id)
  end

  def current_festival
    @current_festival ||= if festival_participant_id.present?
      current_participant&.festival_event
    elsif session[:festival_event_id].present?
      FestivalEvent.find_by(id: session[:festival_event_id])
    end
  end
end
