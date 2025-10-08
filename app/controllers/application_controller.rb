class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :store_user_location!, if: :storable_location?
  before_action :configure_permitted_parameters, if: :devise_controller?

  def configure_permitted_parameters
    # For additional fields in app/views/devise/registrations/new.html.erb
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :role])

    # For additional in app/views/devise/registrations/edit.html.erb
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone_number, :role])
  end

  private
  # Store the original location before Devise intercepts
  def store_user_location!
    session[:user_return_to] = request.fullpath
  end

  # Define which requests should store the location
  def storable_location?
    request.get? && !devise_controller? && !request.xhr? # Only save for GET requests, not Devise/XHR requests
  end

  # Redirect drop_off users to their site manager page after sign in
  def after_sign_in_path_for(resource)
    if resource.drop_off? && resource.drop_off_sites.any?
      if resource.drop_off_sites.count == 1
        drop_off_site_manager_path(resource.drop_off_sites.first)
      else
        drop_off_site_managers_path
      end
    else
      stored_location_for(resource) || root_path
    end
  end
end
