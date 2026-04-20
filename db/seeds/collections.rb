puts "\n--- Seeding collections (date-relative) ---"
puts "  Clearing existing collections and driver days..."
Collection.destroy_all
Bucket.destroy_all
DropOffEvent.destroy_all
DriversDay.destroy_all
puts "  Cleared."

alfred = User.find_by(email: "driver@gooi.com")
unless alfred
  puts "  ✗ No driver found — run 'users' seed first."
  return
end

today = Date.today

# First occurrence of wday on or after a given date
def first_wday_on_or_after(date, wday)
  days_ahead = (wday - date.wday) % 7
  date + days_ahead.days
end

# Realistic bag/bucket count for a completed collection
def collection_volume(plan, buckets_per_collection)
  case plan
  when "XL"         then { buckets: [1.0, 1.0, 2.0, 1.5, 2.0].sample }
  when "Commercial" then { buckets_45l: buckets_per_collection.to_i.clamp(1, 10) }
  else                   { bags: [1, 1, 2, 2, 2, 3].sample }
  end
end

created_collections = 0
sentinel = Date.new(2001, 1, 1)  # sentinel for "unset" holiday dates (DB default 2000-01-01)

# Track users who have already received their first collection in this seed run.
# new_customer: true belongs only on the very first collection a user ever has.
users_with_a_collection = Set.new

# Process subscriptions oldest-first so a user's first sub is always handled
# before their renewals — ensuring new_customer lands on the right record.
Subscription.order(start_date: :asc).find_each do |sub|
  next if sub.collection_day.blank? || sub.start_date.blank?
  next if sub.pending?   # pending subs haven't started
  next if sub.once_off?  # once-off handled by single CreateFirstCollectionJob; skip in bulk seed

  target_wday = Date::DAYNAMES.index(sub.collection_day)
  sub_start   = sub.start_date.to_date

  # Number of non-skipped collections needed for this subscription to complete.
  # Mirrors CheckSubscriptionsForCompletionJob exactly.
  required = (4.2 * sub.duration.to_i).ceil + 1

  # Real holiday window, if set (ignore the 2000-01-01 placeholder)
  has_holiday   = sub.holiday_start.present? && sub.holiday_start > sentinel &&
                  sub.holiday_end.present?   && sub.holiday_end   > sentinel
  holiday_range = has_holiday ? (sub.holiday_start..sub.holiday_end) : nil

  date         = first_wday_on_or_after(sub_start, target_wday)
  non_skipped  = 0
  first_pickup = true
  is_users_first_sub = !users_with_a_collection.include?(sub.user_id)

  loop do
    # ── Stop condition ──────────────────────────────────────────────────────
    if sub.completed?
      # Completed subs stop as soon as the quota is fulfilled.
      # Also cap at today as a safety net for any data oddities.
      break if non_skipped >= required
      break if date > today
    else
      # Active / paused: generate up through next week (the scheduled-but-not-yet-done window).
      # These subs haven't reached `required` yet because their start_date was set recently.
      break if date > today + 7.days
    end

    # ── Determine skip status ───────────────────────────────────────────────
    on_holiday  = holiday_range&.cover?(date) || false
    # ~8% random skip for collections older than 2 weeks (not recent ones — those are reliable)
    random_skip = !on_holiday && date < (today - 14.days) && rand(12) == 0
    skip        = on_holiday || random_skip
    is_done     = date < today && !skip

    non_skipped += 1 unless skip

    # ── Driver's day ────────────────────────────────────────────────────────
    dd = DriversDay.find_or_create_by!(user: alfred, date: date) do |d|
      if date < today
        d.start_kms = rand(50_000..60_000)
        d.end_kms   = rand(60_001..62_000)
      end
    end

    # ── Collection record ───────────────────────────────────────────────────
    # new_customer is only true on a user's very first collection ever —
    # not the first of each renewal, just the absolute first pickup.
    is_first_ever = first_pickup && !skip && is_users_first_sub

    attrs = {
      subscription: sub,
      drivers_day:  dd,
      date:         date,
      is_done:      is_done,
      skip:         skip,
      new_customer: is_first_ever
    }
    attrs.merge!(collection_volume(sub.plan, sub.buckets_per_collection)) if is_done

    Collection.create!(attrs)
    created_collections += 1
    users_with_a_collection.add(sub.user_id)
    first_pickup = false

    date += 7.days
  end
end

puts "  ✓ #{created_collections} collections created"
puts "    done:     #{Collection.where(is_done: true).count}"
puts "    skipped:  #{Collection.where(skip: true).count}"
puts "    upcoming: #{Collection.where(is_done: false, skip: false).count}"
puts "  ✓ #{DriversDay.count} driver days"

# ── Guarantee at least 2 new customers in the current week ───────────────────
# The main loop sets new_customer naturally for each user's first-ever collection.
# If none of those happen to fall this week, promote a few upcoming collections.

this_week_dates = [2, 3, 4].filter_map do |wday|
  d = first_wday_on_or_after(today, wday)
  d if d <= today + 7.days
end

already_new = Collection.where(date: this_week_dates, new_customer: true, skip: false).count
needed      = [0, 2 - already_new].max

if needed > 0
  Collection.where(date: this_week_dates, skip: false, new_customer: false)
            .order("RANDOM()").limit(needed)
            .update_all(new_customer: true)
  puts "  ✓ Promoted #{needed} upcoming collection(s) to new_customer: true"
end

puts "  #{Collection.where(date: this_week_dates, new_customer: true).count} new customer(s) in this week's route"

# ── Stats for the most recent completed driver day ────────────────────────────

most_recent = DriversDay.where(user: alfred)
                        .where("date < ?", today)
                        .order(date: :desc)
                        .first

if most_recent
  household_count = most_recent.collections.where(skip: false).count.clamp(4, 12)

  household_count.times do
    size   = [25, 25, 45].sample
    weight = size == 45 ? rand(6.0..14.0).round(1) : rand(3.5..9.0).round(1)
    Bucket.create!(drivers_day: most_recent, bucket_size: size, weight_kg: weight)
  end

  most_recent.calculate_and_save_statistics!
  stat = most_recent.day_statistic

  puts "\n  ✓ Stats generated for #{most_recent.date.strftime('%A %-d %b')}:"
  puts "    #{most_recent.collections.where(skip: false).count} households  ·  #{most_recent.total_net_kg.round(1)} kg  ·  #{most_recent.total_buckets} buckets"
  puts "    #{stat.avoided_co2e_kg.round(2)} kg CO₂e avoided  ·  #{stat.trees_gross.round(2)} tree-years gross"
else
  puts "  ⚠ No past driver days found"
end
