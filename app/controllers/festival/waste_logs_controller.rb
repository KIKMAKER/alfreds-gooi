class Festival::WasteLogsController < Festival::BaseController
  def index
    @logs = current_festival.festival_waste_logs
                            .includes(:festival_participant)
                            .order(day_number: :asc, logged_at: :asc)

    @totals = current_festival.festival_waste_logs
                              .group(:category)
                              .sum(:weight_kg)
                              .transform_values { |v| v.to_f.round(3) }

    @totals_by_destination = FestivalWasteLog.destinations.keys.index_with do |dest|
      current_festival.festival_waste_logs.organic.where(destination: dest).sum(:weight_kg).to_f.round(3)
    end
  end

  def new
    @log = FestivalWasteLog.new(
      logged_at: Time.current,
      day_number: current_day_number
    )
  end

  def create
    entries = build_log_entries
    if entries.any? && entries.all?(&:valid?)
      entries.each(&:save!)
      redirect_to festival_waste_logs_path, notice: "#{entries.size} measurement(s) saved."
    else
      @log = FestivalWasteLog.new(log_params_base)
      flash.now[:alert] = entries.any? ? "Some entries were invalid." : "Enter at least one weight."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log = current_festival.festival_waste_logs.find(params[:id])
    log.destroy
    redirect_to festival_waste_logs_path, notice: "Entry removed."
  end

  private

  def build_log_entries
    entries = []

    # Organic entry — one per submission, with source + destination flags
    if params[:organic_weight].present?
      entries << current_festival.festival_waste_logs.build(
        festival_participant: current_participant,
        day_number:    params[:day_number],
        logged_at:     params[:logged_at],
        category:      FestivalWasteLog::ORGANIC_CATEGORY,
        weight_kg:     params[:organic_weight],
        source:        params[:organic_source].presence,
        destination:   params[:organic_destination].presence,
        notes:         params[:notes]
      )
    end

    # Inorganic entries — one per filled weight field
    (params[:weights] || {}).each do |category, weight|
      next if weight.blank?
      entries << current_festival.festival_waste_logs.build(
        festival_participant: current_participant,
        day_number:  params[:day_number],
        logged_at:   params[:logged_at],
        category:    category,
        weight_kg:   weight,
        notes:       params[:notes]
      )
    end

    entries
  end

  def log_params_base
    {
      day_number: params[:day_number],
      logged_at: params[:logged_at],
      notes: params[:notes]
    }
  end

  def current_day_number
    return 1 unless current_festival
    days_elapsed = (Date.today - current_festival.start_date).to_i + 1
    days_elapsed.clamp(1, current_festival.day_count)
  end
end
