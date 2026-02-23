class CommercialInquiriesController < ApplicationController
  skip_before_action :authenticate_user!

  # Step 1: Create account for commercial inquiry
  def new_account
    session[:commercial_inquiry] = true
    @user = User.new
  end

  # Step 1: Process account creation
  def create_account
    @user = User.new(account_params)

    if @user.valid?(:account_step)
      # Store account details in session
      session[:inquiry_first_name] = params[:user][:first_name]
      session[:inquiry_last_name] = params[:user][:last_name]
      session[:inquiry_email] = params[:user][:email]
      session[:inquiry_phone_number] = params[:user][:phone_number]
      session[:inquiry_password] = params[:user][:password]

      redirect_to new_commercial_inquiry_details_path
    else
      render :new_account, status: :unprocessable_entity
    end
  end

  # Step 2: Business details and requirements
  def new_details
    unless session[:inquiry_email].present?
      redirect_to root_path, alert: "Please start the inquiry process again"
      return
    end

    @inquiry = CommercialInquiry.new
  end

  # Step 2: Create user + inquiry, send notification
  def create
    # Build user from session data
    @user = User.new(
      first_name: session[:inquiry_first_name],
      last_name: session[:inquiry_last_name],
      email: session[:inquiry_email],
      phone_number: session[:inquiry_phone_number],
      password: session[:inquiry_password],
      password_confirmation: session[:inquiry_password]
    )

    if @user.save
      # Create commercial inquiry
      @inquiry = CommercialInquiry.create!(
        user: @user,
        business_name: params[:commercial_inquiry][:business_name],
        business_address: params[:commercial_inquiry][:business_address],
        estimated_buckets: params[:commercial_inquiry][:estimated_buckets],
        preferred_duration: params[:commercial_inquiry][:preferred_duration],
        collection_frequency: params[:commercial_inquiry][:collection_frequency],
        additional_notes: params[:commercial_inquiry][:additional_notes]
      )

      # Clear session
      clear_inquiry_session

      # Sign in user
      sign_in(@user)

      # Send notification emails
      CommercialInquiryMailer.notify_admin(@inquiry).deliver_now
      CommercialInquiryMailer.notify_customer(@inquiry).deliver_now

      redirect_to commercial_inquiry_confirmation_path
    else
      @inquiry = CommercialInquiry.new(inquiry_params)
      render :new_details, status: :unprocessable_entity
    end
  end

  # Confirmation page
  def confirmation
  end

  private

  def account_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :password, :password_confirmation)
  end

  def inquiry_params
    params.require(:commercial_inquiry).permit(
      :business_name, :business_address, :estimated_buckets,
      :preferred_duration, :collection_frequency, :additional_notes
    )
  end

  def clear_inquiry_session
    session.delete(:commercial_inquiry)
    session.delete(:inquiry_first_name)
    session.delete(:inquiry_last_name)
    session.delete(:inquiry_email)
    session.delete(:inquiry_phone_number)
    session.delete(:inquiry_password)
  end
end
