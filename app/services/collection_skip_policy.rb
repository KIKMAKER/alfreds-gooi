# frozen_string_literal: true

# Decides which collections may be offered a self-service "skip this week" link.
#
# Two kinds of customer are never asked to skip:
#   * once-off customers — a single collection is the whole plan, so skipping it
#     is meaningless.
#   * brand-new customers — we don't invite someone to skip their very first
#     collection.
#
# "New" here is a forward-looking question about an upcoming collection, so it's
# deliberately not DriversDay.new_customer_count_for (a stats metric counting
# collections that have already happened). A customer is new for skip purposes
# if they have at most one collection dated on or before today — that covers
# both "their first collection is the upcoming one" (none yet) and "they've had
# exactly one so far".
class CollectionSkipPolicy
  NEW_CUSTOMER_MAX_PAST_COLLECTIONS = 1

  # Returns a Set of the collection ids that may be offered a skip link.
  def self.eligible_collection_ids(collections)
    collections = collections.to_a
    new_user_ids = new_customer_user_ids(collections)

    collections.filter_map do |collection|
      subscription = collection.subscription
      next if subscription.nil? || subscription.once_off?
      next if new_user_ids.include?(subscription.user_id)

      collection.id
    end.to_set
  end

  # User ids (among the given collections) who are still new customers.
  def self.new_customer_user_ids(collections)
    user_ids = collections.filter_map { |c| c.subscription&.user_id }.uniq
    return [].to_set if user_ids.empty?

    past_counts = Collection.joins(:subscription)
                            .where(subscriptions: { user_id: user_ids })
                            .where(date: ..Date.current)
                            .group("subscriptions.user_id")
                            .count

    # Users with no past collections don't appear in the grouped count at all,
    # so default to 0 — their first collection is the upcoming one.
    user_ids.select { |uid| past_counts.fetch(uid, 0) <= NEW_CUSTOMER_MAX_PAST_COLLECTIONS }.to_set
  end
end
