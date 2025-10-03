# app/helpers/nav_helper.rb
module NavHelper
  def nav_drivers_day
    return nil unless user_signed_in? && current_user.driver?

    # Prefer an existing instance var when you're already on a DriversDay page
    return @drivers_day if defined?(@drivers_day) && @drivers_day.present?

    # Try common param names safely (nested or not), then today, then most recent
    current_user.drivers_days.find_by(id: params[:drivers_day_id]) ||
      current_user.drivers_days.find_by(id: params[:id]) ||
      current_user.drivers_days.find_by(date: Date.current) ||
      current_user.drivers_days.order(date: :desc).first
  end
end
