class DropOffSiteManagersController < ApplicationController
  before_action :authorize_manager!
  before_action :set_drop_off_site, only: [:show, :edit, :update, :submit_letter, :letter_template]

  def index
    @drop_off_sites = current_user.drop_off_sites.order(:collection_day, :name)
  end

  def show
    events = @drop_off_site.drop_off_events
    @recent_events = events.includes(:buckets).order(date: :desc).limit(5)
    @next_event = events.where(is_done: false).where("date >= ?", Date.current).order(:date).first
    @total_kg = events.completed.sum(:weight_kg).to_f
    @total_dropoffs = events.completed.count
    @show_index_link = current_user.drop_off_sites.count > 1

    if @drop_off_site.charges_disposal_fee?
      today = Date.current
      @month_fees = @drop_off_site.fees_for(year: today.year, month: today.month)
    end
  end

  # Lifetime impact across every site this manager runs, the drop-off twin of
  # CustomersController#my_stats.
  def impact
    events = current_user.drop_off_events.completed
    @total_kg = events.sum(:weight_kg).to_f
    @total_dropoffs = events.count
    @protein_kg = events.protein.sum(:weight_kg).to_f
    @since = events.minimum(:date)
    @compost_kg = (@total_kg * User::COMPOST_MULTIPLIER).round
    @co2e_kg = (@total_kg * User::CO2E_MULTIPLIER).round
    @avg_kg = @total_dropoffs.positive? ? @total_kg / @total_dropoffs : 0
    @recent_events = events.includes(:drop_off_site).order(date: :desc).limit(5)
  end

  def history
    @per  = params.fetch(:per, 20).to_i.clamp(1, 100)
    @page = [params.fetch(:page, 1).to_i, 1].max

    scope = current_user.drop_off_events.completed.includes(:drop_off_site, :buckets).order(date: :desc)
    @total = scope.count
    @events = scope.offset((@page - 1) * @per).limit(@per)
    @total_pages = (@total.to_f / @per).ceil
    @multiple_sites = current_user.drop_off_sites.count > 1
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

  # The manager's signed facility confirmation letter goes to Gooi for review. The
  # site is not "listed" (and nothing is paid) until an admin approves it.
  def submit_letter
    return redirect_to(drop_off_site_manager_path(@drop_off_site), notice: "You're already a listed facility.") if @drop_off_site.letter_approved?

    upload = params[:facility_letter]
    if upload.blank?
      redirect_to drop_off_site_manager_path(@drop_off_site), alert: "Please choose your signed letter to upload."
    elsif @drop_off_site.submit_facility_letter(upload)
      notify_admin_of_letter
      redirect_to drop_off_site_manager_path(@drop_off_site), notice: "Thank you! We'll review your letter and confirm shortly."
    else
      redirect_to drop_off_site_manager_path(@drop_off_site), alert: @drop_off_site.errors.full_messages.to_sentence
    end
  end

  def letter_template
    send_file Rails.root.join("lib/documents/gooi-facility-confirmation-letter.docx"),
              filename: "Gooi facility confirmation letter.docx",
              type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              disposition: "attachment"
  end

  private

  # The upload is already saved; a mail failure must not turn it into a 500. The
  # admin dashboard's "awaiting review" count is the backstop.
  def notify_admin_of_letter
    FacilityLetterMailer.submitted(@drop_off_site).deliver_now
  rescue StandardError => e
    Rails.logger.error("Facility letter notification failed for site #{@drop_off_site.id}: #{e.message}")
  end

  def set_drop_off_site
    @drop_off_site = current_user.drop_off_sites.find_by!(slug: params[:id])
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
