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
      stored_location = session[:user_return_to] # Get stored location

      if stored_location
        session.delete(:user_return_to) # Clear after using
        return redirect_to stored_location
      end
      if resource.customer?
        return redirect_to manage_path
      elsif resource.driver?
        # CreateCollectionsJob.perform_now
        return redirect_to vamos_drivers_day_path(resource.drivers_day.last)
      elsif resource.admin?
        return redirect_to this_week_collections_path
      else
        return redirect_to root_path
      end
    end
  end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  protected

  # def after_sign_in_path_for(resource)
  #   if resource.customer?
  #     return manage_path
  #   elsif resource.driver?
  #     CreateCollectionsJob.perform_now
  #     vamos_path
  #   elsif resource.admin?
  #     this_week_collections_path
  #   else
  #     root_path # Fallback in case none of the conditions match
  #   end
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
