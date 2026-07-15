class Admin::IncompleteAddressesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_driver

  def index
    active = Subscription.where(status: "active").includes(:user)
    @subscriptions = active.reject(&:complete_mapbox_address?)
                            .sort_by { |s| [s.suburb_missing_from_address? ? 0 : 1, s.suburb.to_s] }
  end

  private

  def require_admin_or_driver
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin? || current_user.driver?
  end
end
