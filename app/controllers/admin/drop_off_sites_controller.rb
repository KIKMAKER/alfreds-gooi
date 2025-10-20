class Admin::DropOffSitesController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_drop_off_site, only: [:show, :edit, :update, :destroy]

  def index
    @drop_off_sites = DropOffSite.order(:collection_day, :name)
  end

  def show
  end

  def new
    @drop_off_site = DropOffSite.new
  end

  def create
    @drop_off_site = DropOffSite.new(drop_off_site_params)

    if @drop_off_site.save
      redirect_to admin_drop_off_site_path(@drop_off_site), notice: "Drop-off site created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @drop_off_site.update(drop_off_site_params)
      redirect_to admin_drop_off_site_path(@drop_off_site), notice: "Drop-off site updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @drop_off_site.destroy
    redirect_to admin_drop_off_sites_path, notice: "Drop-off site deleted successfully!"
  end

  def create_event
    @drop_off_site = DropOffSite.find(params[:id])

    unless params[:date].present?
      redirect_to admin_drop_off_site_path(@drop_off_site), alert: "Please select a date for the drop-off event."
      return
    end

    date = Date.parse(params[:date])

    # Find or create the drivers_day
    driver = User.find_by(role: 'driver')
    drivers_day = DriversDay.find_or_create_by!(date: date, user: driver)

    # Create the drop-off event
    drop_off_event = DropOffEvent.create!(
      drop_off_site: @drop_off_site,
      drivers_day: drivers_day,
      date: date
    )

    redirect_to admin_drop_off_site_path(@drop_off_site),
                notice: "Drop-off event created for #{date.strftime('%A, %B %e')}!"
  end

  def create_next_week_events
    CreateNextWeekDropOffEventsJob.perform_now
    redirect_to admin_drop_off_sites_path, notice: "Next week's drop-off events created!"
  end

  private

  def set_drop_off_site
    @drop_off_site = DropOffSite.find_by(slug: params[:id]) || DropOffSite.find(params[:id])
  end

  def drop_off_site_params
    params.require(:drop_off_site).permit(
      :name,
      :street_address,
      :suburb,
      :contact_name,
      :phone_number,
      :notes,
      :collection_day,
      :photo,
      :user_id,
      :story,
      :website,
      :instagram_handle,
      :facebook_url
    )
  end

  def authenticate_admin!
    redirect_to root_path unless current_user&.admin?
  end
end
