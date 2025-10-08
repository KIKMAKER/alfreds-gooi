class DropOffSiteManagersController < ApplicationController
  before_action :authorize_manager!
  before_action :set_drop_off_site, only: [:show, :edit, :update]

  def index
    @drop_off_sites = current_user.drop_off_sites.order(:collection_day, :name)
  end

  def show
    @recent_events = @drop_off_site.drop_off_events.order(date: :desc).limit(10)
    @show_index_link = current_user.drop_off_sites.count > 1
  end

  def edit
  end

  def update
    if @drop_off_site.update(drop_off_site_params)
      redirect_to drop_off_site_manager_path(@drop_off_site), notice: "Contact details updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_drop_off_site
    @drop_off_site = current_user.drop_off_sites.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to drop_off_site_managers_path, alert: "Site not found."
  end

  def authorize_manager!
    unless current_user.drop_off? || current_user.admin?
      redirect_to root_path, alert: "Access denied."
      return
    end

    if current_user.drop_off? && current_user.drop_off_sites.empty?
      redirect_to root_path, alert: "You are not associated with any drop-off sites."
    end
  end

  def drop_off_site_params
    params.require(:drop_off_site).permit(:contact_name, :phone_number, :notes)
  end
end
