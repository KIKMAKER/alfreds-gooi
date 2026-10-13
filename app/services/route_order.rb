# The one place that decides "what order is the route in" and makes it stick.
#
# A route day interleaves two kinds of stops that share a single position
# sequence: Collections and DropOffEvents. Three things used to drift apart:
#
#   * today's positions         (collections.position / drop_off_events.position)
#   * the subscription's slot   (subscriptions.collection_order — a rank among
#                                collections ONLY, used as the fallback by the
#                                collection-creating jobs)
#   * next week's positions     (copied from the two above by different jobs,
#                                with different numbering schemes)
#
# so a drag on Tuesday arrived on the next Tuesday with drop-offs shifted or
# tied against collections, or not at all when a subscription failed
# validation. Everything here writes with SQL (no validations or callbacks, so
# a legacy record can never silently veto the save) inside one transaction.
class RouteOrder
  COLLECTION = "collection".freeze
  DROP_OFF   = "drop_off_event".freeze

  Stop = Struct.new(:type, :id, :subscription_id, :site_id, keyword_init: true) do
    def key = [type, id]
  end

  class << self
    # Every stop on the day in route order. Ties (and nils) are broken
    # deterministically — position, then collections before drop-offs, then id —
    # so two page loads can never disagree about the order.
    def stops_for(drivers_day)
      collections = drivers_day.collections.pluck(:id, :subscription_id, :position).map do |id, sub_id, pos|
        [pos, 0, id, Stop.new(type: COLLECTION, id: id, subscription_id: sub_id)]
      end
      drop_offs = drivers_day.drop_off_events.pluck(:id, :drop_off_site_id, :position).map do |id, site_id, pos|
        [pos, 1, id, Stop.new(type: DROP_OFF, id: id, site_id: site_id)]
      end

      (collections + drop_offs)
        .sort_by { |pos, rank, id, _| [pos || Float::INFINITY, rank, id] }
        .map(&:last)
    end

    # Persist a dragged order. `submitted` is an array of { type:, id: } in the
    # order the driver now sees. Unknown or foreign ids are ignored; stops that
    # exist on the day but weren't in the submission (e.g. created after the page
    # loaded) keep their relative order at the end rather than colliding.
    #
    # Returns the number of stops numbered.
    def save!(drivers_day, submitted)
      DriversDay.transaction do
        drivers_day.lock! # serialise overlapping saves for the same day

        current = stops_for(drivers_day)
        by_key  = current.index_by(&:key)

        wanted = Array(submitted).filter_map do |entry|
          by_key[[entry[:type].to_s, entry[:id].to_i]]
        end.uniq
        ordered = wanted + (current - wanted)

        write_positions!(ordered)
        sync_subscription_orders!(ordered)

        target = next_week_day(drivers_day)
        carry_forward!(drivers_day, target) if target

        ordered.size
      end
    end

    # The same weekday next week, if its DriversDay has been created already.
    def next_week_day(drivers_day)
      date = drivers_day.date + 7
      DriversDay.where(date: date, user_id: drivers_day.user_id).order(:id).first ||
        (DriversDay.where(date: date).one? ? DriversDay.find_by(date: date) : nil)
    end

    # Reproduce `from`'s route on `to` (normally the same weekday, a week on).
    #
    # Collections follow their subscription. Drop-offs follow their site and are
    # re-anchored to the subscription whose collection they came after — so a
    # drop-off between Anna and Ben stays between Anna and Ben even if someone
    # joined or left in the meantime. Stops with no counterpart (new customers,
    # new sites) go to the end, in their existing order.
    def carry_forward!(from, to)
      return 0 if to.nil? || from.id == to.id

      source = stops_for(from)
      return 0 if source.empty?

      DriversDay.transaction do
        sub_rank = {}
        source.each { |s| sub_rank[s.subscription_id] ||= sub_rank.size if s.type == COLLECTION }

        target_collections = stops_for(to).select { |s| s.type == COLLECTION }
                                          .each_with_index
                                          .sort_by { |s, i| [sub_rank[s.subscription_id] || Float::INFINITY, i] }
                                          .map(&:first)
        target_by_sub = target_collections.each_with_index.to_h { |s, i| [s.subscription_id, i] }

        # For each source drop-off: the subscriptions that preceded it, nearest first.
        anchors_by_site = {}
        preceding = []
        source.each do |s|
          if s.type == COLLECTION
            preceding.unshift(s.subscription_id)
          else
            anchors_by_site[s.site_id] ||= preceding.dup
          end
        end

        target_drop_offs = stops_for(to).select { |s| s.type == DROP_OFF }
        placed   = Hash.new { |h, k| h[k] = [] } # collection index (-1 = start) => drop-offs
        leftover = []
        target_drop_offs.each do |drop_off|
          anchors = anchors_by_site[drop_off.site_id]
          if anchors
            idx = anchors.filter_map { |sub_id| target_by_sub[sub_id] }.first || -1
            placed[idx] << drop_off
          else
            leftover << drop_off
          end
        end

        ordered = placed[-1].dup
        target_collections.each_with_index do |collection, i|
          ordered << collection
          ordered.concat(placed[i])
        end
        ordered.concat(leftover)

        write_positions!(ordered)
        sync_subscription_orders!(ordered)
        ordered.size
      end
    end

    private

    # One UPDATE per table: position = 1..n across the interleaved list.
    def write_positions!(ordered)
      { COLLECTION => Collection, DROP_OFF => DropOffEvent }.each do |type, model|
        rows = ordered.each_with_index.filter_map { |s, i| [s.id, i + 1] if s.type == type }
        bulk_assign(model, :position, rows)
      end
    end

    # subscriptions.collection_order = rank among collections only. Written with
    # update_all so neither validations nor Subscription#sync_collection_positions
    # (which would flatten future days back to collections-only numbering) run.
    def sync_subscription_orders!(ordered)
      rows = ordered.select { |s| s.type == COLLECTION && s.subscription_id }
                    .each_with_index
                    .map { |s, i| [s.subscription_id, i + 1] }
      bulk_assign(Subscription, :collection_order, rows)
    end

    def bulk_assign(model, column, rows)
      return if rows.empty?

      whens = rows.map { |id, value| "WHEN #{Integer(id)} THEN #{Integer(value)}" }.join(" ")
      model.where(id: rows.map(&:first)).update_all("#{column} = CASE id #{whens} END")
    end
  end
end
