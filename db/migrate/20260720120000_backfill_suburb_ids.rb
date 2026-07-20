class BackfillSuburbIds < ActiveRecord::Migration[7.2]
  # Inlined snapshot (not read from models) so this migration keeps working
  # after Subscription::LEGACY_TO_CANONICAL / Interest::SUBURBS are edited or removed.
  LEGACY_TO_CANONICAL = {
    "Devil's Peak Estate"            => "Vredehoek",
    "Zonnebloem (District Six)"      => "District Six",
    "Walmer Estate (District Six)"   => "District Six",
    "Lower Vrede (District Six)"     => "District Six",
  }.freeze

  # Interest's separate "unserviced areas" list, minus the literal "Other" sentinel
  # (which becomes suburb_id: nil, not a fake Suburb row).
  INTEREST_TARGET_SUBURBS = [
    "Athlone", "Bellville", "Bellville South", "Bloubergstrand", "Bothasig",
    "Brackenfell", "Brooklyn", "Century City", "Crawford", "Durbanville",
    "Edgemead", "Elsies River", "Epping", "Glencairn", "Goodwood",
    "Gugulethu", "Hanover Park", "Khayelitsha", "Kommetjie", "Kraaifontein",
    "Kuils River", "Langa", "Lansdowne", "Lentegeur", "Maitland",
    "Manenberg", "Milnerton", "Mitchells Plain", "Monte Vista",
    "Montague Gardens", "Noordhoek", "Nyanga", "Ocean View", "Ottery",
    "Paarden Eiland", "Parow", "Parklands", "Pelikan Park", "Phillippi",
    "Pinelands", "Red Hill", "Richwood", "Rugby", "Scarborough",
    "Simon's Town", "Strandfontein", "Sunningdale", "Surrey Estate",
    "Table View", "Thornton", "Wetton", "Ysterplaat"
  ].freeze

  def up
    backfill_target_suburbs
    suburb_ids_by_name = Suburb.pluck(:name, :id).to_h

    backfill_table(:subscriptions, suburb_ids_by_name)
    backfill_table(:drop_off_sites, suburb_ids_by_name)
    backfill_table(:business_profiles, suburb_ids_by_name)
    backfill_interests(suburb_ids_by_name)
  end

  def down
    execute "UPDATE subscriptions SET suburb_id = NULL"
    execute "UPDATE drop_off_sites SET suburb_id = NULL"
    execute "UPDATE business_profiles SET suburb_id = NULL"
    execute "UPDATE interests SET suburb_id = NULL"
  end

  private

  def backfill_target_suburbs
    existing_names = Suburb.pluck(:name)

    (INTEREST_TARGET_SUBURBS - existing_names).each do |name|
      base = name.to_s.downcase.gsub(/[^a-z0-9\s\-]/, "").gsub(/\s+/, "-").strip
      slug = unique_slug_for(base)

      execute <<-SQL
        INSERT INTO suburbs (name, slug, status, created_at, updated_at)
        VALUES (#{quote(name)}, #{quote(slug)}, 3, NOW(), NOW())
      SQL
    end
  end

  def unique_slug_for(base)
    candidate = base
    n = 1
    while execute("SELECT 1 FROM suburbs WHERE slug = #{quote(candidate)}").to_a.any?
      candidate = "#{base}-#{n}"
      n += 1
    end
    candidate
  end

  def backfill_table(table, suburb_ids_by_name)
    rows = execute("SELECT id, suburb FROM #{table} WHERE suburb IS NOT NULL").to_a
    unmatched = []

    rows.each do |row|
      raw_suburb = row["suburb"]
      canonical = LEGACY_TO_CANONICAL.fetch(raw_suburb, raw_suburb)
      suburb_id = suburb_ids_by_name[canonical]

      if suburb_id
        execute "UPDATE #{table} SET suburb_id = #{suburb_id} WHERE id = #{row["id"]}"
      else
        unmatched << raw_suburb
      end
    end

    if unmatched.any?
      raise "Unmatched suburb strings in #{table}, resolve manually before re-running: #{unmatched.uniq.inspect}"
    end
  end

  def backfill_interests(suburb_ids_by_name)
    rows = execute("SELECT id, suburb FROM interests WHERE suburb IS NOT NULL").to_a
    unmatched = []

    rows.each do |row|
      raw_suburb = row["suburb"]
      next if raw_suburb == "Other" # stays suburb_id: nil

      suburb_id = suburb_ids_by_name[raw_suburb]
      if suburb_id
        execute "UPDATE interests SET suburb_id = #{suburb_id} WHERE id = #{row["id"]}"
      else
        unmatched << raw_suburb
      end
    end

    if unmatched.any?
      raise "Unmatched suburb strings in interests, resolve manually before re-running: #{unmatched.uniq.inspect}"
    end
  end
end
