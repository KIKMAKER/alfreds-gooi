class CreateNextWeekDropOffEventsJob < ApplicationJob
  queue_as :default

  def perform
    next_week = Date.today + 7
    puts "Creating drop-off events for #{next_week}"

    process_day(next_week, next_week.wday)
  end

  private

  def process_day(drop_off_date, day_name)
    # Create drivers_day entry
    driver = User.find_by(role: 'driver')
    unless driver
      puts "No driver found! Skipping processing for #{drop_off_date}"
      return
    end

    drivers_day = DriversDay.find_or_create_by!(
      date: drop_off_date,
      user: driver
    )
    puts "Driver's Day processed for #{drop_off_date}: #{drivers_day.user.first_name} with ID: #{drivers_day.id}"

    # Find all drop-off sites assigned to this day
    drop_off_sites = DropOffSite.where(collection_day: day_name)

    drop_off_sites.each do |site|
      # Create drop-off event for this site if it doesn't exist
      drop_off_event = DropOffEvent.find_or_create_by!(
        drivers_day: drivers_day,
        drop_off_site: site,
        date: drop_off_date
      )
      puts "Created drop-off event for #{site.name} on #{drop_off_date} (ID: #{drop_off_event.id})"
    end

    puts "Completed creating #{drop_off_sites.count} drop-off events for #{drop_off_date}"
  end
end
