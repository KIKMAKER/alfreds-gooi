# app/jobs/create_drivers_day_job.rb
class CreateCollectionsJob < ApplicationJob
  queue_as :default

  def perform
    # Only run on Tuesday, Wednesday, and Thursday
    today = Date.today
    if today.tuesday? || today.wednesday? || today.thursday?
      # Create drivers_day entry
      drivers_day = DriversDay.find_or_create_by!(
        date: today,
        user_id: User.find_by(role: 'driver').id
      )
      puts "Driver's Day processed for: #{drivers_day.user.first_name} with id: #{drivers_day.id}"
    end

    # Create collections for each subscription assigned to this day
    subscriptions = Subscription.where(collection_day: today.wday)
    subscriptions.each do |subscription|
      collection = Collection.create!(
        drivers_day: drivers_day,
        subscription: subscription,
        date: today,
        # Add other necessary attributes
      )
      collection.update!(new_customer: true) if subscription.is_new_customer
      collection.update!(skip: true) if today >= subscription.holiday_start && today <= subscription.holiday_end
    end

  end
end
