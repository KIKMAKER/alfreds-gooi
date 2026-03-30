class Admin::CommercialInquiriesController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!
  before_action :set_inquiry, only: [:show, :update]

  def index
    @inquiries = CommercialInquiry.includes(:user).order(created_at: :desc)
  end

  def show
  end

  def update
    @inquiry.update!(status: params[:status])
    redirect_back fallback_location: admin_commercial_inquiries_path,
                  notice: "Marked as #{@inquiry.status}."
  end

  private

  def set_inquiry
    @inquiry = CommercialInquiry.find(params[:id])
  end

  def authenticate_admin!
    redirect_to root_path, alert: "Not authorised." unless current_user&.admin?
  end
end
