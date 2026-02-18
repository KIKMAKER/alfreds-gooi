# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:google_oauth2]

  def google_oauth2
    handle_auth "Google"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed, please try again."
  end

  private

  def handle_auth(kind)
    auth_data = request.env['omniauth.auth']

    # Check if user already exists
    existing_user = User.find_by(provider: auth_data.provider, uid: auth_data.uid)
    is_new_user = existing_user.nil?

    @user = User.from_omniauth(auth_data)

    if @user.persisted?
      sign_in(@user)
      set_flash_message(:notice, :success, kind: kind) if is_navigational_format?

      # Determine redirect based on signup flow
      if session[:oauth_signup_flow] && is_new_user
        # This is a signup - redirect to subscription details (step 2)
        session.delete(:oauth_signup_flow) # Clear the flag
        redirect_to new_subscription_details_path
      else
        # This is a login or existing user - redirect to manage page
        session.delete(:oauth_signup_flow) # Clear flag if it exists
        redirect_to manage_path
      end
    else
      session["devise.#{kind.downcase}_data"] = auth_data.except('extra')
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end
end
