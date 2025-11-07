class BusinessProfilesController < ApplicationController
  before_action :set_subscription
  before_action :authorize_user!

  def new
    @business_profile = @subscription.build_business_profile
  end

  def create
    @business_profile = @subscription.build_business_profile(business_profile_params)

    if @business_profile.save
      redirect_to invoice_path(@subscription.invoices.last), notice: "Business details added successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @business_profile = @subscription.business_profile
  end

  def update
    @business_profile = @subscription.business_profile

    if @business_profile.update(business_profile_params)
      redirect_to invoice_path(@subscription.invoices.last), notice: "Business details updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:subscription_id])
  end

  def authorize_user!
    unless current_user == @subscription.user || current_user.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def business_profile_params
    params.require(:business_profile).permit(
      :business_name,
      :vat_number,
      :contact_person,
      :street_address,
      :suburb,
      :postal_code
    )
  end
end
