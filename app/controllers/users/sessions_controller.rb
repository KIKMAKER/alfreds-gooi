# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    super do |resource|
      # Set a permanent signed cookie so the session can be restored after
      # a PWA restart on iOS (Safari clears session cookies on app close).
      if resource.persisted?
        cookies.permanent.signed[:gooi_user_id] = {
          value:    resource.id,
          httponly: true,
          secure:   Rails.env.production?
        }
      end
    end
  end

  # DELETE /resource/sign_out
  def destroy
    cookies.delete(:gooi_user_id)
    super
  end

  protected

  def after_sign_in_path_for(resource)
    # PRIORITY 1: Admin always lands on the dashboard
    return admin_root_path if resource.admin?

    # PRIORITY 2: Check if user was trying to access a specific path
    stored = stored_location_for(resource)
    if stored.present? && safe_redirect_path?(stored)
      return stored
    end

    # PRIORITY 3: Role-based default redirects (if no stored location)

    if resource.driver?
      today = Time.zone.today
      dd = DriversDay.find_by(user_id: resource.id, date: today)

      # If you *always* expect a DD to exist by login time:
      if dd
        return vamos_drivers_day_path(dd)
      else
        # Fallback (pick what makes sense for you)
        return today_subscriptions_path
        # or: redirect_to new_drivers_day_path(date: today) if you allow manual creation
        # or: DriversDay.create!(user: resource, date: today); redirect_to ...
      end
    end

    return manage_path if resource.customer?

    return drop_off_site_manager_path(resource.drop_off_sites.first) if resource.drop_off?

    # PRIORITY 3: Final fallback
    root_path
  end

  private

  # simple safety: only allow relative, non-auth paths
  def safe_redirect_path?(path)
    uri = URI.parse(path) rescue nil
    uri && uri.host.nil? && !path.start_with?("/users/") && path != '/'
  end


  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
