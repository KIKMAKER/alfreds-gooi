class CreateCollectionsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    next_collection_date = Date.today + 7
    day_name = next_collection_date.strftime("%A")
    process_day(next_collection_date, day_name)
    Rails.logger.info "Ran Create Collection Job"

    # Check for monthly invoices that need to be generated
    MonthlyInvoiceService.process_all
    Rails.logger.info "Checked for monthly invoices to generate"
  end

  private

  def process_day(collection_date, day_name)
    driver = User.find_by(role: 'driver')
    unless driver
      Rails.logger.warn "No driver found! Skipping processing for #{collection_date}"
      return
    end

    drivers_day = DriversDay.find_or_create_by!(
      date: collection_date,
      user: driver
    )
    Rails.logger.info "Driver's Day created for #{collection_date}: #{drivers_day.user.first_name} (ID: #{drivers_day.id})"

      subscriptions = Subscription.where(collection_day: day_name, status: "active")

      subscriptions.find_each do |subscription|

        collection = Collection.find_or_create_by!(
          drivers_day: drivers_day,
        subscription: subscription,
        date: collection_date
      )
      if subscription.holiday_start && subscription.holiday_end && collection.date.between?(subscription.holiday_start, subscription.holiday_end)
        collection.mark_skipped!(by: nil, reason: "holiday")
      end

      collection.mark_skipped!(by: nil, reason: "paused") if subscription.is_paused?

      collection.update!(new_customer: true) if subscription.is_new_customer

      Rails.logger.info "Created collection for #{subscription.customer_id} on #{collection_date}"
    end

  end
end
