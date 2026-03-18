class InterestsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create, :success] if defined?(Devise)
  protect_from_forgery with: :exception

  def create
    # simple honeypot: drop if the hidden field is filled
    return redirect_to interest_success_path(suburb: "your area") if params[:website].present?

    interest = Interest.new(interest_params)
    if interest.save
      InterestMailer.with(interest: interest).new_interest_email.deliver_later
      InterestMailer.with(interest: interest).confirmation_email.deliver_later
      redirect_to interest_success_path(suburb: interest.suburb)
    else
      redirect_back fallback_location: root_path,
                    alert: interest.errors.full_messages.to_sentence
    end
  end

  def success
    @suburb = params[:suburb].presence || "your area"
  end

  private

  def interest_params
    params.require(:interest).permit(:name, :email, :suburb, :note)
  end
end
