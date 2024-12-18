# app/jobs/create_drivers_day_job.rb
class CreateTodayCollectionsJob < ApplicationJob
  queue_as :default

  def perform

    today = Date.today
    puts "#{today}"
    # Define the days to process
    # days_to_process = { "Tuesday" => 1, "Wednesday" => 2, "Thursday" => 3 }

    # days_to_process.each do |day_name, day_offset|
    process_day(today, today.wday)
    # end
  end

  def process_day(today, day_name)
    # Create drivers_day entry
    drivers_day = DriversDay.find_or_create_by!(
      date: today,
      user_id: User.find_by(role: 'driver').id
    )
    puts "Driver's Day processed for #{day_name}: #{drivers_day.user.first_name} with id: #{drivers_day.id}"

    # Create collections for each subscription assigned to this day
    subscriptions = Subscription.where(collection_day: day_name)
    subscriptions.each do |subscription|
      collection = Collection.create!(
        drivers_day: drivers_day,
        subscription: subscription,
        date: today,
        skip: subscription.is_paused?
      )
      puts ">> >> >> #{subscription.customer_id}"
      collection.update!(new_customer: true) if subscription.is_new_customer
    end
  end
end
