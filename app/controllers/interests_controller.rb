class InterestsController < ApplicationController
  skip_before_action :authenticate_user!, only: :create if defined?(Devise)
  protect_from_forgery with: :exception

  def create
    # simple honeypot: drop if the hidden field is filled
    return redirect_back fallback_location: root_path, notice: "Thanks!" if params[:website].present?

    interest = Interest.new(interest_params)
    if interest.save
      redirect_back fallback_location: root_path,
                    notice: "Thank you — one step closer to compost collection! 🌱"
    else
      redirect_back fallback_location: root_path,
                    alert: interest.errors.full_messages.to_sentence
    end
  end

  private

  def interest_params
    params.require(:interest).permit(:name, :email, :suburb, :note)
  end
end
