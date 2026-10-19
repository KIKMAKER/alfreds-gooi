class ApplicationController < ActionController::Base
  before_action :restore_session_from_cookie
  before_action :authenticate_user!
  before_action :store_user_location!, if: :storable_location?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :drop_off_home_path_for

  # Track current user for Ahoy analytics
  def ahoy_user
    current_user
  end

  def configure_permitted_parameters
    # For additional fields in app/views/devise/registrations/new.html.erb
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :role])

    # For additional in app/views/devise/registrations/edit.html.erb
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone_number, :role])
  end

  private

  # Restore Devise session from permanent cookie after a PWA restart.
  # iOS Safari clears session cookies when a standalone PWA is closed.
  # The signed cookie set on login survives the restart and lets us silently
  # sign the user back in without a re-login prompt.
  def restore_session_from_cookie
    return if current_user

    user_id = cookies.signed[:gooi_user_id]
    return unless user_id

    user = User.find_by(id: user_id)
    sign_in(user, store: true) if user
  end

  # Store the original location before Devise intercepts
  def store_user_location!
    session[:user_return_to] = request.fullpath
  end

  # Define which requests should store the location
  def storable_location?
    request.get? && !devise_controller? && !request.xhr? # Only save for GET requests, not Devise/XHR requests
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    elsif resource.drop_off? && resource.drop_off_sites.any?
      drop_off_home_path_for(resource)
    elsif resource.customer?
      manage_path
    else
      stored_location_for(resource) || root_path
    end
  end

  # Home for a drop-off site manager: straight to the site when they have one,
  # the site picker when they run several.
  def drop_off_home_path_for(user)
    sites = user.drop_off_sites
    return drop_off_site_managers_path unless sites.count == 1

    drop_off_site_manager_path(sites.first)
  end

  def after_sign_up_path_for(resource)
    resource.customer? ? manage_path : root_path
  end
end
