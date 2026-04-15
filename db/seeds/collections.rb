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

# Helper: first occurrence of wday on or after a given date
def first_wday_on_or_after(date, wday)
  days_ahead = (wday - date.wday) % 7
  date + days_ahead.days
end

# Helper: realistic bag/bucket count for a collection
def collection_volume(plan, buckets_per_collection)
  case plan
  when "XL"       then { buckets: [1.0, 1.0, 2.0, 1.5, 2.0].sample }
  when "Commercial" then { buckets_45l: buckets_per_collection.to_i.clamp(1, 10) }
  else                 { bags: [1, 1, 2, 2, 2, 3].sample }
  end
end

created_collections = 0
created_driver_days = 0

Subscription.find_each do |sub|
  next if sub.collection_day.blank? || sub.start_date.blank?
  next if sub.pending?  # Pending subs haven't started yet

  target_wday  = Date::DAYNAMES.index(sub.collection_day)
  sub_start    = sub.start_date.to_date

  # End of range: completed subs stop at their end_date; active/paused extend one week ahead
  sub_end = case sub.status.to_sym
            when :completed
              (sub.end_date || sub_start + sub.duration.to_i.months).to_date
            else
              today + 7.days
            end

  next if sub_start > sub_end

  # Detect real holiday windows (default DB value is 2000-01-01 — ignore those)
  sentinel      = Date.new(2001, 1, 1)
  has_holiday   = sub.holiday_start.present? && sub.holiday_start > sentinel &&
                  sub.holiday_end.present?   && sub.holiday_end   > sentinel
  holiday_range = has_holiday ? (sub.holiday_start..sub.holiday_end) : nil

  date = first_wday_on_or_after(sub_start, target_wday)

  first_collection = true

  while date <= sub_end
    on_holiday = holiday_range&.cover?(date) || false

    # ~8% random skips for past collections that are old enough to not be "just happened"
    random_skip = !on_holiday && date < (today - 14.days) && rand(12) == 0

    skip    = on_holiday || random_skip
    is_done = date < today && !skip

    # Find or create the DriversDay for this date
    dd = DriversDay.find_or_create_by!(user: alfred, date: date) do |d|
      # Only set kms for past days; leave future days bare so driver can fill in
      if date < today
        d.start_kms = rand(50_000..60_000)
        d.end_kms   = rand(60_001..62_000)
      end
      created_driver_days += 1
    end

    attrs = {
      subscription: sub,
      drivers_day:  dd,
      date:         date,
      is_done:      is_done,
      skip:         skip,
      new_customer: first_collection && !skip
    }

    if is_done && !skip
      attrs.merge!(collection_volume(sub.plan, sub.buckets_per_collection))
    end

    Collection.create!(attrs)
    created_collections += 1
    first_collection = false

    date += 7.days
  end
end

puts "  ✓ #{created_collections} collections created"
puts "    done:     #{Collection.where(is_done: true).count}"
puts "    skipped:  #{Collection.where(skip: true).count}"
puts "    upcoming: #{Collection.where(is_done: false, skip: false).count}"
puts "  ✓ #{DriversDay.count} driver days"

# ── Stats for the most recent completed driver day ────────────────────────────
# Find the most recent past day that has collections, and give it bucket weight
# data so the DayStatistic is populated for the impact dashboard.

most_recent = DriversDay.where(user: alfred)
                        .where("date < ?", today)
                        .order(date: :desc)
                        .first

if most_recent
  bucket_count = most_recent.collections.where(skip: false).count.clamp(4, 12)

  bucket_count.times do
    size = [25, 25, 45].sample
    # Net weight after tare: ~4–11 kg realistic for a 25L household bucket
    weight = case size
             when 45 then rand(6.0..14.0).round(1)
             else         rand(3.5..9.0).round(1)
             end
    Bucket.create!(drivers_day: most_recent, bucket_size: size, weight_kg: weight)
  end

  # Bucket.after_commit has already updated total_net_kg/total_buckets on the DriversDay.
  # Now generate the full DayStatistic (CO₂, trees, per-bucket averages, etc.)
  most_recent.calculate_and_save_statistics!

  puts "\n  ✓ Stats generated for #{most_recent.date.strftime('%A %-d %b')}:"
  stat = most_recent.day_statistic
  puts "    #{most_recent.collections.where(skip: false).count} households  ·  #{most_recent.total_net_kg.round(1)} kg  ·  #{most_recent.total_buckets} buckets"
  puts "    #{stat.avoided_co2e_kg.round(2)} kg CO₂e avoided  ·  #{stat.trees_gross.round(2)} tree-years gross"
else
  puts "  ⚠ No past driver days found — run again after creating subscriptions with past start dates"
end
