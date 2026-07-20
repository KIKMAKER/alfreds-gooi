class CreateSuburbs < ActiveRecord::Migration[7.2]
  def change
    create_table :suburbs do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :status, null: false, default: 0 # active/drop_off_only/waitlist/target

      t.timestamps
    end
    add_index :suburbs, :name, unique: true
    add_index :suburbs, :slug, unique: true

    reversible do |dir|
      dir.up { backfill_suburbs }
    end
  end

  private

  # Snapshot of Subscription::SUBURBS and DropOffSite::DROP_OFF_ONLY_SUBURBS at the
  # time this migration was written. Inlined (rather than read from the models) so
  # this migration keeps working correctly regardless of later model changes.
  def backfill_suburbs
    active = ["Bakoven", "Bantry Bay", "Camps Bay", "Cape Town", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "District Six", "Ndabeni", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Woodstock", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Observatory", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "Southfield", "Steenberg", "Tokai", "Witteboomen", "Wynberg", "Clovelly", "Fish Hoek", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"]
    drop_off_only = ["Langa", "Philippi", "Epping"]

    used_slugs = []

    (active + drop_off_only).uniq.each do |name|
      status = drop_off_only.include?(name) ? 1 : 0
      slug = unique_slug_for(name, used_slugs)
      used_slugs << slug

      execute <<-SQL
        INSERT INTO suburbs (name, slug, status, created_at, updated_at)
        VALUES (#{quote(name)}, #{quote(slug)}, #{status}, NOW(), NOW())
      SQL
    end
  end

  def unique_slug_for(name, used_slugs)
    base = name.to_s.downcase.gsub(/[^a-z0-9\s\-]/, "").gsub(/\s+/, "-").strip
    candidate = base
    n = 1
    while used_slugs.include?(candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    candidate
  end
end
