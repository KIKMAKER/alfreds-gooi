class DriversDaysController < ApplicationController
  before_action :set_drivers_day, only: %i[drop_off edit update destroy collections]

  def route
    selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today

    @drivers_day = DriversDay.find_or_create_by!(date: selected_date, user_id: User.find_by(first_name: "Alfred").id)

    # Get collections ordered by subscription's optimized route order
    collections = @drivers_day.collections
                              .includes(:subscription, :user)
                              .joins(:subscription)
                              .order('subscriptions.collection_order NULLS LAST')
                              .to_a

    Rails.logger.info "=== ROUTE DEBUG ==="
    Rails.logger.info "Total collections: #{collections.count}"
    Rails.logger.info "First 5 collections with their subscription.collection_order:"
    collections.first(5).each do |c|
      Rails.logger.info "  - #{c.subscription.user.first_name}: collection_order=#{c.subscription.collection_order}, position=#{c.position}"
    end

    # Update position field to match the optimized order (for manual sorting/drag-drop)
    collections.each_with_index do |collection, index|
      new_position = index + 1
      collection.update_column(:position, new_position) unless collection.position == new_position
    end

    Rails.logger.info "After updating positions:"
    collections.first(5).each do |c|
      Rails.logger.info "  - #{c.subscription.user.first_name}: collection_order=#{c.subscription.collection_order}, position=#{c.position}"
    end

    drop_off_events = @drivers_day.drop_off_events.includes(:drop_off_site).order(:position).to_a

    # Combine collections and drop-off events, sorted by position
    @route_items = (collections + drop_off_events).sort_by(&:position)

    Rails.logger.info "Final @route_items (first 5):"
    @route_items.first(5).each do |item|
      if item.is_a?(Collection)
        Rails.logger.info "  - Collection: #{item.subscription.user.first_name}, position=#{item.position}"
      else
        Rails.logger.info "  - DropOffEvent: #{item.drop_off_site.name}, position=#{item.position}"
      end
    end
    Rails.logger.info "==================="
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
    @stat = @drivers_day.day_statistic
    @collections = @drivers_day.collections
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
    @subscriptions = Subscription.where(collection_day: @today, status: 'active').order('collection_order NULLS LAST')
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
      You can log in to alfred.gooi.me/manage with email #{@user.email} and your password should be 'password' unless you have changed it.
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
  end

  def edit; end

  def update
    if @drivers_day.update(drivers_day_params)
      redirect_to root_path, notice: 'Driver\'s day was successfully updated.'
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
