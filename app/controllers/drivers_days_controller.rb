class DriversDaysController < ApplicationController
  before_action :set_drivers_day, only: %i[drop_off edit update destroy collections]

  def route
    selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today

    @drivers_day = DriversDay.find_or_create_by!(date: selected_date, user_id: User.find_by(first_name: "Alfred").id)

    # Load collections ordered by position (nulls last = newly added collections appear at end)
    collections = @drivers_day.collections
                                .includes(:subscription, :user)
                                .order(Arel.sql("position ASC NULLS LAST"))

    drop_off_events = @drivers_day.drop_off_events.includes(:drop_off_site).order(:position)

    # Combine collections and drop-off events, sorted by position (nil sorts to end)
    @route_items = (collections.to_a + drop_off_events.to_a).sort_by { |item| item.position || Float::INFINITY }
  end


  def vamos
    # Morning briefing before starting the day
    today = Date.today
    @today = today.strftime("%A")

    @drivers_day = DriversDay.find(params[:id])

    if @drivers_day
      @collections = @drivers_day.collections
      @skip_collections = @collections.where(skip: true)
      @new_customers = @collections.select { |collection| collection.new_customer == true }
      @count = @collections.count - @skip_collections.count - (@new_customers.any? ? @new_customers.count : 0)
      @bags_needed = @collections.select { |collection| collection.needs_bags }
    else
      @collections = []
      @new_customers = []
      @count = 0
      @bags_needed = []
    end
  end

  def complete
    # Stats dashboard after completing the day
    today = Date.today
    @today = today.strftime("%A")

    @drivers_day = DriversDay.find(params[:id])
    @collections = @drivers_day.collections
    @stat = @drivers_day.day_statistic

    # Prepare snapshot card variables
    if @stat
      # Get new customers count from collections (not in day_statistic)
      @new_customers = @collections.where(new_customer: true).distinct.count(:subscription_id)

      # Derived calculations
      @compost_kg = (@stat.net_kg * 0.35).round # 35% conversion rate
      @landfill_m3 = (@stat.net_kg / 400.0).round(1) # ~400kg per m³ density

      # Format values for display
      @kg_diverted = @stat.net_kg.round
      @customers_served = @stat.households
      @buckets_diverted = @stat.full_equiv
      @co2_avoided = @stat.avoided_co2e_kg.round
      @trees_equivalent = @stat.trees_net.round
    end
  end


  def start
    # in production today will be the current day,
    # today = "Wednesday"
    # PRODUCTION
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = (Date.today + 1)
    @today = today.strftime("%A")
    alfred = User.find_by(first_name: "Alfred", role: 'driver')
    # ##
    @drivers_day = DriversDay.find_or_create_by(date: today, user: alfred)
    @subscriptions = Subscription.where(collection_day: @today, status: 'active')
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last&.needs_bags && subscription.collections.last.needs_bags > 0}
    @total_bags_needed = @bags_needed.sum { |subscription| subscription.collections.last.needs_bags }
    @new_customer = @subscriptions.select { |subscription| subscription.collections.last&.new_customer == true }
    @products_needed = @drivers_day.products_needed_for_delivery

    # Check for recently lapsed customers
    two_weeks_ago = today - 2.weeks
    existing_ids = @drivers_day.collections.pluck(:subscription_id)

    @recently_lapsed = Subscription
      .where(collection_day: Date::DAYNAMES[today.wday])
      .where(status: 'completed')
      .where(end_date: two_weeks_ago..today)
      .where.not(id: existing_ids)
      .includes(:user, :collections)
      .order(end_date: :desc)

    # Filter to only those who had collections in their last week
    @recently_lapsed = @recently_lapsed.select do |sub|
      last_week = sub.end_date - 1.week
      sub.collections.where('date >= ? AND date <= ?', last_week, sub.end_date).where(skip: false).any?
    end

    if request.patch?
      # Set start_time when form is actually submitted (only if not already set)
      @drivers_day.start_time ||= Time.current
      @drivers_day.save!

      if update_drivers_day(drivers_day_params, next_path: today_subscriptions_path)
        # puts "Driver's Day started at: #{current_user.drivers_days.last.start_time}"
        flash[:notice] = "Day started successfully"
      else
        flash.now[:alert] = "Failed to start the Day"
        render :start
      end
    end
  end

  def end
    @drivers_day = DriversDay.includes(:collections).find(params[:id])

    return unless request.patch?

    # Set end_time when form is actually submitted
    @drivers_day.end_time = Time.current
    @drivers_day.save!

    if update_drivers_day(drivers_day_params, next_path: complete_drivers_day_path(@drivers_day))
      # Calculate and save statistics
      @drivers_day.calculate_and_save_statistics!

      # Send daily snapshot email now that stats exist
      DailySnapshotMailer.report(drivers_day_id: @drivers_day.id).deliver_now

      # Run background jobs
      CreateCollectionsJob.perform_now
      CreateNextWeekDropOffEventsJob.perform_now
      CheckSubscriptionsForCompletionJob.perform_now

      puts "Driver's Day ended at: #{@drivers_day.end_time}"
      flash[:notice] = "Day ended successfully with #{@drivers_day.end_kms} kms on the bakkie."
    else
      flash.now[:alert] = "Failed to end the Day"
      render :end
    end
  end

  def missing_customers
    @drivers_day = DriversDay.find(params[:id])
    @today = @drivers_day.date
    # Get all subscriptions for today that do not already have a collection
    existing_ids = @drivers_day.collections.pluck(:subscription_id)

    @missing_subs = Subscription
                    .where(collection_day: @today.wday)
                    .where.not(id: existing_ids)
                    .where(end_date: 1.month.ago.to_date..@today)
                    .where.not(status: "legacy")
                    .includes(:user)
  end

  def create_missing_collection
    @drivers_day = DriversDay.find(params[:id])
    subscription = Subscription.find(params[:subscription_id])

    collection = Collection.create!(
      subscription: subscription,
      drivers_day: @drivers_day,
      date: @drivers_day.date,
      bags: 0,
      skip: false,
      new_customer: false,
      buckets: 0.0
    )

    redirect_to whatsapp_message_drivers_day_path(@drivers_day, user_id: subscription.user_id)
  end

  def whatsapp_message
    @drivers_day = DriversDay.find(params[:id])
    @user = User.find(params[:user_id])
    @subscription = @user.subscriptions.order(created_at: :desc).first

    @message = <<~MSG.strip
      Hello #{@user.first_name}! You weren't on my list today because you haven't renewed your subscription yet, but I am collecting your gooi bag anyway!
      Please resubscribe before next week so that you will be on my list then :)
      You can log in to alfred.gooi.me/manage with email #{@user.email}.
    MSG

    @whatsapp_url = @user.generate_whatsapp_link(@message)
  end

  def collections
    date = @drivers_day.date
    @collections = @drivers_day.collections.includes(:subscription).where(date: date).order(date: :desc)
  end

  def index
    # fetch all instances of drivers day with necessary data with .includes
    @drivers_days = DriversDay.includes(:day_statistic).order(date: :desc)
  end

  def show
    @drivers_day = DriversDay.find(params[:id])
    @collections = @drivers_day.collections
    @stat = @drivers_day.day_statistic

    # Prepare snapshot card variables
    if @stat
      # Get new customers count from collections (not in day_statistic)
      @new_customers = @collections.where(new_customer: true).distinct.count(:subscription_id)

      # Derived calculations
      @compost_kg = (@stat.net_kg * 0.35).round # 35% conversion rate
      @landfill_m3 = (@stat.net_kg / 400.0).round(1) # ~400kg per m³ density

      # Format values for display
      @kg_diverted = @stat.net_kg.round
      @customers_served = @stat.households
      @buckets_diverted = @stat.full_equiv
      @co2_avoided = @stat.avoided_co2e_kg.round
      @trees_equivalent = @stat.trees_net.round
    end

  end

  def snapshot
    @drivers_day = DriversDay.find(params[:id])
    @collections = @drivers_day.collections
    @stat = @drivers_day.day_statistic

    # Prepare snapshot card variables (same as show action)
    if @stat
      @new_customers = @collections.where(new_customer: true).distinct.count(:subscription_id)
      @compost_kg = (@stat.net_kg * 0.35).round
      @landfill_m3 = (@stat.net_kg / 400.0).round(1)
      @kg_diverted = @stat.net_kg.round
      @customers_served = @stat.households
      @buckets_diverted = @stat.full_equiv
      @co2_avoided = @stat.avoided_co2e_kg.round
      @trees_equivalent = @stat.trees_net.round
    end

    render layout: 'snapshot'
  end

  def yearly_snapshot
    # Get year from params or default to 2025
    year = params[:year]&.to_i || 2025

    # Fetch all drivers_days and their stats for the year
    @drivers_days = DriversDay
      .includes(:day_statistic, :collections)
      .where('extract(year from drivers_days.date) = ?', year)
      .where.not(day_statistic: { id: nil })
      .order('drivers_days.date': :asc)

    if @drivers_days.empty?
      flash[:alert] = "No data found for #{year}"
      redirect_to drivers_days_path and return
    end

    # Aggregate statistics
    stats = @drivers_days.map(&:day_statistic).compact

    @year = year
    @total_days = @drivers_days.count
    @kg_diverted = stats.sum(&:net_kg).round
    @compost_kg = (@kg_diverted * 0.35).round
    @landfill_m3 = (@kg_diverted / 400.0).round(1)
    @co2_avoided = stats.sum(&:avoided_co2e_kg).round
    @trees_equivalent = stats.sum(&:trees_net).round
    @buckets_diverted = stats.sum(&:full_equiv).round

    # Calculate unique customers served throughout the year
    all_subscription_ids = @drivers_days.flat_map { |dd| dd.collections.pluck(:subscription_id) }.uniq
    @customers_served = all_subscription_ids.count

    # Calculate new customers (first collection in the year)
    @new_customers = @drivers_days.flat_map do |dd|
      dd.collections.where(new_customer: true).pluck(:subscription_id)
    end.uniq.count

    # Monthly breakdown
    @monthly_data = @drivers_days.group_by { |dd| dd.date.beginning_of_month }.map do |month, days|
      month_stats = days.map(&:day_statistic).compact
      {
        month: month,
        days_count: days.count,
        kg_collected: month_stats.sum(&:net_kg).round,
        households: days.flat_map { |d| d.collections.pluck(:subscription_id) }.uniq.count,
        co2_avoided: month_stats.sum(&:avoided_co2e_kg).round
      }
    end.sort_by { |m| m[:month] }

    render layout: 'snapshot'
  end

  def edit; end

  def update
    if @drivers_day.update(drivers_day_params)
      redirect_to drivers_days_path, notice: 'Driver\'s day was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @drivers_day.collections.update_all(drivers_day_id: nil)

    @drivers_day.destroy
    redirect_to drivers_days_path, note: "Drivers Day deleted"
  end

  private

  def set_drivers_day
    @drivers_day = DriversDay.find(params[:id])
  end

  def update_drivers_day(params, next_path:)
    if @drivers_day.update(params)
      redirect_to next_path
    else
      render :edit # or the appropriate view for re-editing
    end
  end

  def drivers_day_params
    params.require(:drivers_day).permit(:start_time, :end_time, :sfl_time, :start_kms, :end_kms, :note, :total_buckets, :date, :message_from_alfred, :note)
  end
end
