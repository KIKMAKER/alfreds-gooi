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

  private

  def set_drop_off_site
    @drop_off_site = DropOffSite.find(params[:id])
  end

  def drop_off_site_params
    params.require(:drop_off_site).permit(
      :name,
      :street_address,
      :suburb,
      :contact_name,
      :phone_number,
      :notes,
      :collection_day
    )
  end

  def authenticate_admin!
    redirect_to root_path unless current_user&.admin?
  end
end
