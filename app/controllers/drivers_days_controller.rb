class DriversDaysController < ApplicationController
  skip_before_action :authenticate_user!, only: [:snapshot, :yearly_snapshot]
  before_action :set_drivers_day, only: %i[drop_off edit update destroy collections]

  def route
    selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today

    @drivers_day = DriversDay.find_or_create_by!(date: selected_date, user_id: User.find_by(first_name: "Alfred").id)

    @prev_day = DriversDay.where(date: ...@drivers_day.date).order(date: :desc).first
    @next_day = DriversDay.where(date: (@drivers_day.date + 1)..).order(date: :asc).first

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
      @collections = @drivers_day.collections.includes(:subscription)
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
    @subscriptions = Subscription.where(collection_day: @today, status: 'active').preload(:collections)
    @skip_subscriptions = @subscriptions.select { |s| s.collections.max_by(&:id)&.skip == true }
    @bags_needed        = @subscriptions.select { |s| (c = s.collections.max_by(&:id)) && c.needs_bags.to_i > 0 }
    @total_bags_needed  = @bags_needed.sum { |s| s.collections.max_by(&:id).needs_bags }
    @new_customer       = @subscriptions.select { |s| s.collections.max_by(&:id)&.new_customer == true }
    @products_needed = @drivers_day.products_needed_for_delivery

    # Check for recently lapsed customers
    two_weeks_ago = today - 2.weeks
    existing_ids = @drivers_day.collections.pluck(:subscription_id)
    resubscribed_user_ids = Subscription.where(status: %w[active pending]).pluck(:user_id).uniq

    @recently_lapsed = Subscription
      .where(collection_day: Date::DAYNAMES[today.wday])
      .where(status: 'completed')
      .where(end_date: two_weeks_ago..today)
      .where.not(id: existing_ids)
      .where.not(user_id: resubscribed_user_ids)
      .includes(:user, :collections)
      .order(end_date: :desc)

    # Filter to only those who had collections in their last week (in-memory — collections already preloaded)
    @recently_lapsed = @recently_lapsed.select do |sub|
      last_week = sub.end_date - 1.week
      sub.collections.any? { |c| c.date >= last_week && c.date <= sub.end_date && !c.skip }
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

      # Run background jobs — wrapped so a job failure never 500s the end-of-day flow
      [
        -> { CreateCollectionsJob.perform_now(@drivers_day.date.to_s) },
        -> { CreateNextWeekDropOffEventsJob.perform_now },
        -> { CheckSubscriptionsForCompletionJob.perform_now }
      ].each do |job|
        begin
          job.call
        rescue => e
          Rails.logger.error("[end_drivers_day] Job failed: #{e.class} — #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        end
      end

      Rails.logger.info("Driver's Day #{@drivers_day.id} ended at #{@drivers_day.end_time}")
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
    @collections = @drivers_day.collections
                               .includes(subscription: :user)
                               .where(date: date)
                               .order(position: :asc)
  end

  def index
    @drivers_days = DriversDay
      .with_active_collection_counts
      .includes(:day_statistic, :buckets, :drop_off_events)
      .order(date: :desc)
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

    subscription_ids = @collections.pluck(:subscription_id)

    # Prepare snapshot card variables (same as show action)
    if @stat
      @new_customers = Subscription.active
        .where(id: subscription_ids)
        .joins(:collections)
        .group("subscriptions.id")
        .having("MIN(collections.date) = ?", @drivers_day.date)
        .count
        .size
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

    day_ids = @drivers_days.map(&:id)
    collections_by_day = Collection.where(drivers_day_id: day_ids)
                                   .pluck(:drivers_day_id, :subscription_id, :new_customer)
                                   .group_by(&:first)

    all_subscription_ids = collections_by_day.values.flat_map { |rows| rows.map { |r| r[1] } }.uniq
    @customers_served = all_subscription_ids.count

    @new_customers = collections_by_day.values
                                       .flat_map { |rows| rows.select { |r| r[2] }.map { |r| r[1] } }
                                       .uniq.count

    # Monthly breakdown
    @monthly_data = @drivers_days.group_by { |dd| dd.date.beginning_of_month }.map do |month, days|
      month_stats = days.map(&:day_statistic).compact
      month_day_ids = days.map(&:id)
      month_sub_ids = collections_by_day.values_at(*month_day_ids).compact.flat_map { |rows| rows.map { |r| r[1] } }.uniq
      {
        month: month,
        days_count: days.count,
        kg_collected: month_stats.sum(&:net_kg).round,
        households: month_sub_ids.count,
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

  def reorder
    @drivers_day = DriversDay.find(params[:id])
    items = params[:items] || []

    items.each_with_index do |item_data, index|
      case item_data[:type]
      when "collection"
        @drivers_day.collections
                    .find_by(id: item_data[:id])
                    &.update_column(:position, index + 1)
      when "drop_off_event"
        @drivers_day.drop_off_events
                    .find_by(id: item_data[:id])
                    &.update_column(:position, index + 1)
      end
    end

    # Keep subscription collection_order in sync
    @drivers_day.collections.order(:position).each_with_index do |c, i|
      c.subscription&.update_column(:collection_order, i + 1)
    end

    head :no_content
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
