puts "\n--- Seeding suburbs ---"

# A fresh `db:reset` loads schema.rb and never runs the data-backfilling migrations
# (20260720103529_create_suburbs / 20260720110000_add_collection_day_to_suburbs),
# so the suburbs table is empty and every Subscription/DropOffSite seed would fail.
# Mirrors those migrations: same names, same day lists, same "first day wins" order.
BY_DAY = {
  "Monday"    => ["Woodstock", "De Waterkant", "Bo-Kaap", "Foreshore"],
  "Tuesday"   => ["Bergvliet", "Bishopscourt", "Claremont", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kirstenhof", "Meadowridge", "Newlands", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "Southfield", "Steenberg", "Tokai", "Wynberg", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"],
  "Wednesday" => ["Mowbray", "Observatory", "Bakoven", "Bantry Bay", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Schotsche Kloof", "Constantia", "Witteboomen"],
  "Thursday"  => ["Gardens", "Higgovale", "District Six", "Oranjezicht", "Cape Town", "Salt River", "Tamboerskloof", "University Estate", "Vredehoek", "Observatory"]
}.freeze
DROP_OFF_ONLY = ["Langa", "Philippi", "Epping"].freeze

day_for = {}
BY_DAY.each { |day, names| names.each { |name| day_for[name] ||= day } }

day_for.each do |name, day|
  Suburb.find_or_create_by!(name: name) do |s|
    s.status         = :active
    s.collection_day = day
  end
end

DROP_OFF_ONLY.each do |name|
  Suburb.find_or_create_by!(name: name) { |s| s.status = :drop_off_only }
end

puts "  ✓ #{Suburb.count} suburbs (#{Suburb.active.count} active, #{Suburb.drop_off_only.count} drop-off only)"
