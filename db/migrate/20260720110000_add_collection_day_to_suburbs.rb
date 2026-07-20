class AddCollectionDayToSuburbs < ActiveRecord::Migration[7.2]
  def change
    add_column :suburbs, :collection_day, :integer
    add_index :suburbs, :collection_day

    reversible do |dir|
      dir.up { backfill_collection_days }
    end
  end

  private

  # Snapshot of Subscription::MONDAY_SUBURBS/TUESDAY_SUBURBS/WEDNESDAY_SUBURBS/
  # THURSDAY_SUBURBS at the time this migration was written, inlined (not read
  # from the model) so this migration keeps working after those constants are
  # removed. Checked in the same Monday->Tuesday->Wednesday->Thursday priority
  # order as Subscription#set_collection_day's if/elsif chain, so a suburb that
  # (like "Observatory" today) appears in two day lists resolves to the same
  # day the current runtime code would pick.
  # enum :collection_day, Date::DAYNAMES -> Sunday=0, Monday=1, Tuesday=2, Wednesday=3, Thursday=4
  def backfill_collection_days
    by_day = {
      1 => ["Woodstock", "De Waterkant", "Bo-Kaap", "Foreshore"],
      2 => ["Bergvliet", "Bishopscourt", "Claremont", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kirstenhof", "Meadowridge", "Newlands", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "Southfield", "Steenberg", "Tokai", "Wynberg", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"],
      3 => ["Mowbray", "Observatory", "Bakoven", "Bantry Bay", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Schotsche Kloof", "Constantia", "Witteboomen"],
      4 => ["Gardens", "Higgovale", "District Six", "Oranjezicht", "Cape Town", "Salt River", "Tamboerskloof", "University Estate", "Vredehoek", "Observatory"],
    }

    assigned = {}
    by_day.each do |day_value, names|
      names.each { |name| assigned[name] ||= day_value }
    end

    assigned.each do |name, day_value|
      execute <<-SQL
        UPDATE suburbs SET collection_day = #{day_value} WHERE name = #{quote(name)}
      SQL
    end
  end
end
