class CreateCollectionsJob < ApplicationJob
  queue_as :default

  def perform(from_date = nil)
    anchor = from_date ? Date.parse(from_date.to_s) : Date.today
    next_collection_date = anchor + 7
    day_name = next_collection_date.strftime("%A")
    process_day(next_collection_date, day_name)
    Rails.logger.info "Ran Create Collection Job"

    # Check for monthly invoices that need to be generated
    MonthlyInvoiceService.process_all
    Rails.logger.info "Checked for monthly invoices to generate"
  end

  private

  # For users with multiple active subs in the same suburb, keep only the one
  # furthest along (most completed collections). This handles the early-resub case
  # without doubling Alfred's stops. Commercial customers at different suburbs
  # on the same day are unaffected since they group separately.
  def deduplicate_by_suburb(subscriptions)
    grouped = subscriptions.to_a.group_by { |s| [s.user_id, s.street_address] }

    winner_ids = grouped.flat_map do |(_user_id, address), subs|
      if subs.size == 1
        [subs.first.id]
      else
        winner = subs.min_by(&:created_at)
        Rails.logger.info "Overlap: user #{winner.user_id} has #{subs.size} active subs at #{address}, using sub ##{winner.id}"
        [winner.id]
      end
    end

    subscriptions.where(id: winner_ids)
  end

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

    subscriptions = deduplicate_by_suburb(
      Subscription.where(collection_day: day_name, status: "active")
    )

    subscriptions.find_each do |subscription|

      collection = Collection.find_or_create_by!(
        drivers_day: drivers_day,
        subscription: subscription,
        date: collection_date
      )
      collection.update_column(:position, subscription.collection_order) if collection.position.nil? && subscription.collection_order.present?
      if subscription.holiday_start && subscription.holiday_end && collection.date.between?(subscription.holiday_start, subscription.holiday_end)
        collection.mark_skipped!(by: nil, reason: "holiday")
      end

      collection.mark_skipped!(by: nil, reason: "paused") if subscription.is_paused?

      collection.update!(new_customer: true) if subscription.is_new_customer

      Rails.logger.info "Created collection for #{subscription.customer_id} on #{collection_date}"
    end

  end
end
