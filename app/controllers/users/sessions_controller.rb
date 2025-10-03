# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    super
    # do |resource|
    #   stored_location = session[:user_return_to] # Get stored location
    #   raise

    #   if stored_location
    #     session.delete(:user_return_to) # Clear after using
    #     return redirect_to stored_location
    #   end
    #   if resource.customer?
    #     return redirect_to manage_path
    #   elsif resource.driver?
    #     # CreateCollectionsJob.perform_now
    #     return redirect_to vamos_drivers_day_path(resource.drivers_day.last)
    #   elsif resource.admin?
    #     return redirect_to this_week_collections_path
    #   else
    #     return redirect_to root_path
    #   end
    # end
  end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  protected

  def after_sign_in_path_for(resource)
    # PRIORITY: role-based
    return this_week_collections_path if resource.admin?

    if resource.driver?
      today = Time.zone.today
      dd = DriversDay.find_by(user_id: resource.id, date: today)

      # If you *always* expect a DD to exist by login time:
      if dd
        return vamos_drivers_day_path(dd)
      else
        # Fallback (pick what makes sense for you)
        return today_subscriptions_path, alert: "No Driver’s Day found for today yet."
        # or: redirect_to new_drivers_day_path(date: today) if you allow manual creation
        # or: DriversDay.create!(user: resource, date: today); redirect_to ...
      end
    end

    return manage_path if resource.customer?

    # FALLBACK: use Devise helper (fetches & clears) if you still want “return to”
    stored = stored_location_for(resource)
    if stored.present? && safe_redirect_path?(stored)
      return stored
    end

    root_path
  end

  private

  # simple safety: only allow relative, non-auth paths
  def safe_redirect_path?(path)
    uri = URI.parse(path) rescue nil
    uri && uri.host.nil? && !path.start_with?("/users/")
  end


  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
