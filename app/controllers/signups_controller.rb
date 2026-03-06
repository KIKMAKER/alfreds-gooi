class SignupsController < ApplicationController
  skip_before_action :authenticate_user!

  # Step 1: Create account (name, email, phone, password)
  def new_account
    @plan = params[:plan]
    @duration = params[:duration]
    @discount_code = params[:discount_code]
    @referral_code = params[:referral]
    @buckets_per_collection = params[:buckets_per_collection]

    # Store subscription details in session
    session[:signup_plan] = @plan
    session[:signup_duration] = @duration
    session[:signup_discount_code] = @discount_code
    session[:signup_referral_code] = @referral_code
    session[:signup_buckets_per_collection] = @buckets_per_collection

    @user = User.new
  end

  # Step 1: Process account creation
  def create_account
    # Validate account details
    @user = User.new(account_params)

    if @user.valid?(:account_step)
      # Store account details in session
      session[:signup_first_name] = params[:user][:first_name]
      session[:signup_last_name] = params[:user][:last_name]
      session[:signup_email] = params[:user][:email]
      session[:signup_phone_number] = params[:user][:phone_number]
      session[:signup_password] = params[:user][:password]

      redirect_to new_subscription_details_path
    else
      # Restore plan details for re-rendering
      @plan = session[:signup_plan]
      @duration = session[:signup_duration]
      @discount_code = session[:signup_discount_code]
      @referral_code = session[:signup_referral_code]
      @buckets_per_collection = session[:signup_buckets_per_collection]

      render :new_account, status: :unprocessable_entity
    end
  end

  # Step 2: Subscription details (address)
  def new_subscription_details
    # Redirect back if no account info in session
    unless session[:signup_email].present?
      redirect_to root_path, alert: "Please start the signup process again"
      return
    end

    @plan = session[:signup_plan]
    @duration = session[:signup_duration]
    @discount_code = session[:signup_discount_code]
    @referral_code = session[:signup_referral_code]
    @buckets_per_collection = session[:signup_buckets_per_collection]

    @subscription = Subscription.new
  end

  # Step 2: Create user + subscription
  def create_subscription
    # Build user from session data
    @user = User.new(
      first_name: session[:signup_first_name],
      last_name: session[:signup_last_name],
      email: session[:signup_email],
      phone_number: session[:signup_phone_number],
      password: session[:signup_password],
      password_confirmation: session[:signup_password]
    )

    # Use discount/referral from form if provided, otherwise from session
    discount_code = params[:discount_code].presence || session[:signup_discount_code]
    referral_code = (params[:referral_code].presence || session[:signup_referral_code])&.strip&.upcase
    @user.referred_by_code = referral_code if referral_code.present?

    # Build subscription with address details
    @user.subscriptions.build(subscription_params.merge(
      plan: session[:signup_plan],
      duration: session[:signup_duration],
      discount_code: discount_code,
      referral_code: referral_code,
      buckets_per_collection: session[:signup_buckets_per_collection],
      is_paused: true
    ))

    if @user.save
      # Clear session data
      clear_signup_session

      # Sign in the user
      sign_in(@user)

      subscription = @user.subscriptions.first
      referee = referral_code.present? ? User.find_by(referral_code: referral_code) : nil

      InvoiceBuilder.new(
        subscription: subscription,
        og: nil,
        is_new: true,
        referee: referee
      ).call

      # Send welcome emails
      UserMailer.with(subscription: subscription).welcome.deliver_now
      UserMailer.with(subscription: subscription).sign_up_alert.deliver_now

      redirect_to welcome_subscription_path(subscription)
    else
      # Restore plan details for re-rendering
      @plan = session[:signup_plan]
      @duration = session[:signup_duration]
      @discount_code = session[:signup_discount_code]
      @referral_code = session[:signup_referral_code]
      @buckets_per_collection = session[:signup_buckets_per_collection]

      @subscription = @user.subscriptions.first

      render :new_subscription_details, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :password, :password_confirmation)
  end

  def subscription_params
    params.require(:subscription).permit(:street_address, :suburb, :apartment_unit_number)
  end

  def clear_signup_session
    session.delete(:signup_plan)
    session.delete(:signup_duration)
    session.delete(:signup_discount_code)
    session.delete(:signup_referral_code)
    session.delete(:signup_buckets_per_collection)
    session.delete(:signup_first_name)
    session.delete(:signup_last_name)
    session.delete(:signup_email)
    session.delete(:signup_phone_number)
    session.delete(:signup_password)
  end
end
