class CreateFirstCollectionJob < ApplicationJob
  queue_as :default

  def perform(subscription)
    collection_date = if subscription.once_off? && subscription.start_date.present?
                        subscription.start_date
                      else
                        subscription.calculate_next_collection_day
                      end
    day_name = collection_date.strftime('%A')
    process_day(collection_date, day_name, subscription)
  end

  private

  def process_day(collection_date, day_name, subscription)
    driver = User.find_by(role: 'driver')
    drivers_day = nil

    if driver
      drivers_day = DriversDay.find_or_create_by!(date: collection_date, user: driver)
      puts "Driver's Day processed for #{collection_date}: #{drivers_day.user.first_name} with ID: #{drivers_day.id}"
    else
      puts "Warning: no driver found — collection for #{collection_date} created without a DriversDay"
    end

    collection = Collection.find_or_create_by!(subscription: subscription, date: collection_date)
    collection.update!(drivers_day: drivers_day) if drivers_day && collection.drivers_day.nil?
    puts "Created collection for subscription #{subscription.customer_id} on #{collection_date}"

    collection.update!(new_customer: true) if subscription.is_new_customer
    collection
  end
end
