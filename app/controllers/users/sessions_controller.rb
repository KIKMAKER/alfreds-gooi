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
  end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  protected

  def after_sign_in_path_for(resource)
    puts "User signed in with role: #{resource.role}"
    if resource.customer?
      puts "Redirecting to manage_path"
      manage_path
    elsif resource.driver?
      CreateCollectionsJob.perform_now
      puts "Redirecting to vamos_path"
      vamos_path
    elsif resource.admin?
      puts "Redirecting to vamos_path"
      vamos_path
    else
      puts "Redirecting to root_path"
      root_path # Fallback in case none of the conditions match
    end
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
