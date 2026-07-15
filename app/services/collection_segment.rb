# frozen_string_literal: true

# Classifies each collection's customer into one message segment. A customer has
# exactly one segment; precedence is plan first, then newness:
#
#   1. commercial   — Commercial plan (business relationship dominates)
#   2. once_off     — once-off plan (a single collection is the whole plan)
#   3. new_customer — a Standard/XL customer on (about) their first collection
#   4. standard     — an established Standard/XL customer
#
# Only the standard segment is offered a skip link (see CollectionSkipPolicy).
class CollectionSegment
  SEGMENTS = %i[standard new_customer once_off commercial].freeze

  # "New" is forward-looking: at most one collection dated on or before today,
  # which covers both "first collection is the upcoming one" (none yet) and
  # "they've had exactly one so far".
  NEW_CUSTOMER_MAX_PAST_COLLECTIONS = 1

  # { collection_id => segment_symbol } for the given collections.
  def self.for_collections(collections)
    collections = collections.to_a
    new_user_ids = new_customer_user_ids(collections)

    collections.each_with_object({}) do |collection, by_id|
      by_id[collection.id] = segment_for(collection.subscription, new_user_ids)
    end
  end

  def self.segment_for(subscription, new_user_ids)
    return :standard if subscription.nil?
    return :commercial if subscription.Commercial?
    return :once_off if subscription.once_off?
    return :new_customer if new_user_ids.include?(subscription.user_id)

    :standard
  end

  # User ids (among the given collections) who are still new customers.
  def self.new_customer_user_ids(collections)
    user_ids = collections.filter_map { |c| c.subscription&.user_id }.uniq
    return Set.new if user_ids.empty?

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
