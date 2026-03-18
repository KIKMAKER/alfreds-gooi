class Admin::InterestsController < ApplicationController
  before_action :authenticate_admin!

  def index
    @interests = Interest.order(created_at: :desc)
    @by_suburb = @interests.group_by(&:suburb)
                           .sort_by { |_, entries| -entries.size }
  end

  private

  def authenticate_admin!
    redirect_to root_path unless current_user&.admin?
  end
end
