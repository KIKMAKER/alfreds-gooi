class CreateFirstCollectionJob < ApplicationJob
  queue_as :default

  def perform(subscription)
    today = Date.today
    puts "Today is #{today}"
    next_collection_date = subscription.calculate_next_collection_day
    day_name = next_collection_date.strftime('%A')
    process_day(next_collection_date, day_name, subscription)
  end

  private

  def process_day(collection_date, day_name, subscription)
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

    # Create collection for subscription

    collection = Collection.create!(
      drivers_day: drivers_day,
      subscription: subscription,
      date: collection_date,
      skip: subscription.is_paused?
    )
    puts "Created collection for subscription #{subscription.customer_id} on #{collection_date}"

    # Update the collection if the subscription is new
    collection.update!(new_customer: true) if subscription.is_new_customer

  end
end
