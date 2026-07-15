# frozen_string_literal: true

# Decides which collections may be offered a self-service "skip this week" link.
# Only established Standard/XL customers are — i.e. the "standard" segment.
# Commercial, once-off and brand-new customers are never asked (see
# CollectionSegment for the full precedence and the reasoning).
class CollectionSkipPolicy
  # Returns a Set of the collection ids that may be offered a skip link.
  def self.eligible_collection_ids(collections)
    CollectionSegment.for_collections(collections)
                     .select { |_id, segment| segment == :standard }
                     .keys
                     .to_set
  end
end
