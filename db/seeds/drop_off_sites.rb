puts "\n--- Seeding drop-off sites ---"

alfred = User.find_or_create_by!(email: "driver@gooi.com") do |u|
  u.first_name   = "Alfred"
  u.last_name    = "Mbonjwa"
  u.password     = "password"
  u.role         = "driver"
  u.phone_number = "+27785325513"
end

def seed_drop_off_sites_with_users(sites)
  sites.each do |site_data|
    user = User.find_or_create_by!(email: site_data[:email]) do |u|
      u.first_name  = site_data[:contact_name].split.first
      u.last_name   = site_data[:contact_name].split.last || ""
      u.password    = "password"
      u.role        = "drop_off"
      u.phone_number = site_data[:phone_number]
    end
    puts "  ✓ User: #{user.first_name} (#{user.email})"

    site = DropOffSite.find_or_create_by!(name: site_data[:name]) do |s|
      s.street_address = site_data[:street_address]
      s.suburb         = site_data[:suburb]
      s.contact_name   = site_data[:contact_name]
      s.phone_number   = site_data[:phone_number]
      s.notes          = site_data[:notes]
      s.collection_day = site_data[:collection_day]
      s.user           = user
    end

    site.update!(user: user) if site.user.nil?
    puts "  ✓ Site: #{site.name} (#{site.collection_day}s)"
  end
end

drop_off_sites_data = [
  {
    name:            "Neighbourhood Farm",
    street_address:  "Paris Road, Fish Hoek",
    suburb:          "Fish Hoek",
    contact_name:    "Sibusiso",
    phone_number:    "+27825551234",
    email:           "sibusiso@neighbourhoodfarm.co.za",
    notes:           "Last stop on Tuesday route. Enter through main gate.",
    collection_day:  "Tuesday"
  },
  {
    name:            "Soil For Life",
    street_address:  "Brounger Road, Sillery",
    suburb:          "Constantia",
    contact_name:    "Sarah Green",
    phone_number:    "+27217944982",
    email:           "sarah@soilforlife.co.za",
    notes:           "Last stop on Wednesday route. Drop-off area at back of property.",
    collection_day:  "Wednesday"
  },
  {
    name:            "Streetscapes Farm",
    street_address:  "Upper Orange Street",
    suburb:          "Vredehoek",
    contact_name:    "Richard",
    phone_number:    "+27834567890",
    email:           "richard@streetscapes.co.za",
    notes:           "Last stop on Thursday route. Ring bell at entrance.",
    collection_day:  "Thursday"
  }
]

seed_drop_off_sites_with_users(drop_off_sites_data)

# ── Drop-off events + buckets (5 weeks of history per site) ──────────────────

puts "\n  Seeding drop-off events and buckets..."

site_wday = {
  "Neighbourhood Farm" => 2,  # Tuesday
  "Soil For Life"      => 3,  # Wednesday
  "Streetscapes Farm"  => 4   # Thursday
}

drop_off_sites_data.each do |site_data|
  site        = DropOffSite.find_by!(name: site_data[:name])
  target_wday = site_wday[site.name]
  next unless target_wday

  past_dates = []
  d = Date.today - 1
  while past_dates.size < 5
    past_dates << d if d.wday == target_wday
    d -= 1
  end

  past_dates.each do |event_date|
    dd = DriversDay.find_or_create_by!(user: alfred, date: event_date) do |day|
      day.start_kms = rand(50_000..60_000)
      day.end_kms   = rand(60_001..62_000)
    end

    next if DropOffEvent.exists?(drop_off_site: site, date: event_date)

    bucket_count    = rand(3..6)
    total_weight_kg = rand(12.0..32.0).round(1)
    per_bucket_kg   = (total_weight_kg / bucket_count).round(2)

    event = DropOffEvent.create!(
      drop_off_site:   site,
      drivers_day:     dd,
      date:            event_date,
      is_done:         true,
      weight_kg:       total_weight_kg,
      buckets_dropped: bucket_count
    )

    bucket_count.times do
      Bucket.create!(
        drivers_day:    dd,
        drop_off_event: event,
        weight_kg:      per_bucket_kg,
        bucket_size:    [25, 25, 45].sample
      )
    end

    puts "    #{site.name} #{event_date}: #{bucket_count} buckets, #{total_weight_kg} kg"
  end

  site.recalc_totals!
end

puts "\n  ✓ #{DropOffSite.count} drop-off sites seeded"
puts "  ✓ #{DropOffEvent.count} drop-off events"
puts "  ✓ #{Bucket.where.not(drop_off_event_id: nil).count} buckets attached to events"
puts "\n  Drop-off site logins (password: 'password'):"
drop_off_sites_data.each do |s|
  site = DropOffSite.find_by!(name: s[:name])
  puts "    #{s[:email]}  →  #{site.name} (#{site.collection_day}s, #{site.total_dropoffs_count} events)"
end
