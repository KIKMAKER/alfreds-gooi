# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create, :new]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  def new
    @plan = params[:plan]
    @duration = params[:duration]
  
    super
  end

  # POST /resource
  def create
    super
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [subscriptions_attributes: [:plan, :duration, :street_address, :suburb, :referral_code, :discount_code]])
  end



  # def after_sign_up_path_for(resource)
  #   if resource.persisted?
  #     @subscription = Subscription.create!(
          # user_id: resource.id,
          # plan: params[:user][:subscription][:plan],
          # duration: params[:user][:subscription][:duration],
          # street_address: params[:user][:subscription][:street_address],
          # suburb: params[:user][:subscription][:suburb],
          # is_new_customer: true)
  #     if @subscription
  #       UserMailer.with(subscription: @subscription).welcome.deliver_now
  #       UserMailer.with(subscription: @subscription).sign_up_alert.deliver_now
  #       welcome_subscription_path(@subscription)
  #     else
  #       redirect_to new_user_registration_path(plan: params[:user][:subscription][:plan], duration: params[:user][:subscription][:duration], street_address: params[:user][:subscription][:street_address], suburb: params[:user][:subscription][:suburb])
  #     end
  #   else
  #     redirect_to new_user_registration_path(plan: params[:user][:subscription][:plan], duration: params[:user][:subscription][:duration], street_address: params[:user][:subscription][:street_address], suburb: params[:user][:subscription][:suburb])
  #   end]
  #   # resource.create_initial_invoice
  #   # subscription = resource.subscriptions.first
  #   # invoice = subscription.invoices.first``
  # end

  def after_sign_up_path_for(resource)
    if resource.persisted?
      begin
        @subscription = Subscription.create!(
          user_id: resource.id,
          plan: subscriptions.first.plan,
          duration: subscriptions.first.duration,
          street_address: subscriptions.first.street_address,
          suburb: subscriptions.first.suburb,
          is_new_customer: true,
          referral_code: subscriptions.first.referral_code
        )
        if subscription_params[:discount_code].present?
          code = DiscountCode.find_by(code: subscription_params[:discount_code].to_s.strip.upcase)

          if code&.available?
            @subscription.discount_code = code
            @subscription.save!
          end
        end


        UserMailer.with(subscription: @subscription).welcome.deliver_now
        UserMailer.with(subscription: @subscription).sign_up_alert.deliver_now
        welcome_subscription_path(@subscription)

      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create subscription: #{e.message}"
        redirect_to new_user_registration_path(
          plan: subscriptions.first.plan,
          duration: subscriptions.first.duration,
          street_address: subscriptions.first.street_address,
          suburb: subscriptions.first.suburb
        )
      end
    end

  end


end
