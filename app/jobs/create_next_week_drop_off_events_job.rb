class CreateNextWeekDropOffEventsJob < ApplicationJob
  queue_as :default

  def perform
    next_week = Date.today + 7
    puts "Creating drop-off events for #{next_week}"

    process_day(next_week)
  end

  private

  def process_day(drop_off_date)
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

    # Find last week's DriversDay for the same day to replicate its drop-off events
    this_week_drivers_day = DriversDay.find_by(date: Date.today)

    if this_week_drivers_day
      # Get drop-off events from last week and recreate them for this week
      this_week_events = this_week_drivers_day.drop_off_events

      this_week_events.each do |this_event|
        # Create drop-off event for the same site this week
        drop_off_event = DropOffEvent.find_or_create_by!(
          drivers_day: drivers_day,
          drop_off_site: this_event.drop_off_site,
          date: drop_off_date
        )
        puts "Created drop-off event for #{this_week_drivers_day.drop_off_event.drop_off_site.name} on #{drop_off_date} (ID: #{drop_off_event.id})"
      end

      puts "Completed creating #{this_week_events.count} drop-off events for #{drop_off_date} based on last week"
    else
      puts "No DriversDay found for #{drop_off_date} - skipping drop-off event creation"
      puts "Tip: Manually create drop-off events for this day, and they'll auto-replicate next week"
    end
  end
end
