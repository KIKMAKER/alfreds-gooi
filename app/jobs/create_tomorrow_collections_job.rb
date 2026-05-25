class CreateTomorrowCollectionsJob < ApplicationJob
  queue_as :default

  def perform

    tomorrow = Date.today + 1
    puts "#{tomorrow}"
    # Define the days to process
    # days_to_process = { "Tuesday" => 1, "Wednesday" => 2, "Thursday" => 3 }

    # days_to_process.each do |day_name, day_offset|
    process_day(tomorrow, tomorrow.wday)
    # end
  end

  def process_day(tomorrow, day_name)
    # Create drivers_day entry
    drivers_day = DriversDay.find_or_create_by!(
      date: tomorrow,
      user_id: User.find_by(role: 'driver').id
    )
    puts "Driver's Day processed for #{day_name}: #{drivers_day.user.first_name} with id: #{drivers_day.id}"

    # Create collections for each subscription assigned to this day
    subscriptions = Subscription.where(collection_day: day_name, status: "active")
    subscriptions.each do |subscription|
      next if subscription.once_off?

      skip_reason = if subscription.holiday_covers?(tomorrow)
        "holiday"
      elsif subscription.is_paused
        "paused"
      end

      collection = Collection.find_or_create_by!(
        drivers_day: drivers_day,
        subscription: subscription,
        date: tomorrow
      )
      collection.update_column(:position, subscription.collection_order) if collection.position.nil? && subscription.collection_order.present?
      collection.skip_silently!(reason: skip_reason) if skip_reason
      puts ">> >> >> #{subscription.customer_id}"
      collection.update!(new_customer: true) if subscription.is_new_customer
    end
  end
end
