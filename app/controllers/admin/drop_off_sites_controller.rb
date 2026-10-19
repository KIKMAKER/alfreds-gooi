class Admin::DropOffSitesController < Admin::BaseController
  before_action :set_drop_off_site, only: [:show, :edit, :update, :destroy, :approve_letter, :reject_letter]

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

    if @drop_off_site.save(context: :onboarding)
      approve_if_admin_uploaded_letter
      redirect_to admin_drop_off_site_path(@drop_off_site), notice: "Drop-off site created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @drop_off_site.update(drop_off_site_params)
      approve_if_admin_uploaded_letter
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
    @drop_off_site = DropOffSite.find_by(slug: params[:id]) || DropOffSite.find(params[:id])

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
      date: date,
      waste_stream: @drop_off_site.default_waste_stream
    )

    redirect_to admin_drop_off_site_path(@drop_off_site),
                notice: "Drop-off event created for #{date.strftime('%A, %B %e')}!"
  end

  def create_next_week_events
    CreateNextWeekDropOffEventsJob.perform_now
    redirect_to admin_drop_off_sites_path, notice: "Next week's drop-off events created!"
  end

  def approve_letter
    unless @drop_off_site.facility_confirmation_letter.attached?
      return redirect_to(admin_drop_off_site_path(@drop_off_site), alert: "There is no letter to approve.")
    end

    @drop_off_site.approve_letter!
    deliver_to_manager(:approved)
    redirect_to admin_drop_off_site_path(@drop_off_site), notice: "#{@drop_off_site.name} is now a listed facility."
  end

  def reject_letter
    @drop_off_site.reject_letter!(params[:reason])
    deliver_to_manager(:rejected)
    redirect_to admin_drop_off_site_path(@drop_off_site), notice: "Letter rejected. #{@drop_off_site.name} has been asked to upload a new one."
  end

  private

  # A letter uploaded by an admin has been seen by an admin, so it needs no review.
  def approve_if_admin_uploaded_letter
    return if params.dig(:drop_off_site, :facility_confirmation_letter).blank?

    @drop_off_site.approve_letter!
  end

  def deliver_to_manager(kind)
    return unless @drop_off_site.user

    FacilityLetterMailer.public_send(kind, @drop_off_site).deliver_now
  rescue StandardError => e
    Rails.logger.error("Facility letter #{kind} email failed for site #{@drop_off_site.id}: #{e.message}")
  end

  def set_drop_off_site
    @drop_off_site = DropOffSite.find_by(slug: params[:id]) || DropOffSite.find(params[:id])
  end

  def drop_off_site_params
    params.require(:drop_off_site).permit(
      :name,
      :street_address,
      :suburb_id,
      :contact_name,
      :phone_number,
      :notes,
      :collection_day,
      :photo,
      :user_id,
      :story,
      :website,
      :instagram_handle,
      :facebook_url,
      :fee_per_kg,
      :fee_start_date,
      :max_kg_per_delivery,
      :facility_confirmation_letter,
      :accepts_protein
    )
  end
end
