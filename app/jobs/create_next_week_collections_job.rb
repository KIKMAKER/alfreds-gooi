class CreateNextWeekCollectionsJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.today
    puts "Today is #{today}"

    # Define the days of the week to process (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
    days_to_process = { "Tuesday" => 2, "Wednesday" => 3, "Thursday" => 4 }

    # Process collections for each specified day
    days_to_process.each do |day_name, weekday|
      next_collection_date = today.next_occurring(weekday)
      process_day(next_collection_date, weekday)
    end
  end

  private

  def process_day(collection_date, day_name)
    # Create drivers_day entry
    driver = User.find_by(role: 'driver')
    unless driver
      puts "No driver found! Skipping processing for #{collection_date}"
      return
    end

    drivers_day = DriversDay.find_or_create_by!(
      date: collection_date,
      user: driver
    )
    puts "Driver's Day processed for #{collection_date}: #{drivers_day.user.first_name} with ID: #{drivers_day.id}"

    # Create collections for subscriptions assigned to this day
    subscriptions = Subscription.where(collection_day: day_name, status: "active")
    subscriptions.each do |subscription|
      next if subscription.status == "completed" # Skip completed subscriptions
      collection = Collection.find_or_create_by!(
        drivers_day: drivers_day,
        subscription: subscription,
        date: collection_date)

      collection.update!(
        skip: subscription.is_paused?
      )
      puts "Created collection for subscription #{subscription.customer_id} on #{collection_date}"

      # Update the collection if the subscription is new
      collection.update!(new_customer: true) if subscription.is_new_customer
    end
  end
end
