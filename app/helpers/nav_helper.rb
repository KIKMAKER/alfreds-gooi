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

  # Home for a drop-off site manager: straight to the site when they have one,
  # the site picker when they run several. Mirrors after_sign_in_path_for.
  def drop_off_home_path_for(user)
    sites = user.drop_off_sites
    return drop_off_site_managers_path unless sites.count == 1

    drop_off_site_manager_path(sites.first)
  end
end
