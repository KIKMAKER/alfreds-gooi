module ApplicationHelper
  def render_navbar
    if user_signed_in?
      if current_user.driver? || current_user.admin?
        render "shared/driver_navbar"
      else
        render "shared/new_navbar"
      end
    end
    render "shared/new_navbar"
  end
end
