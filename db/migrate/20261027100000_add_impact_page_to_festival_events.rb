class AddImpactPageToFestivalEvents < ActiveRecord::Migration[7.1]
  class MigrationFestivalEvent < ActiveRecord::Base
    self.table_name = "festival_events"
  end

  def up
    add_column :festival_events, :slug, :string
    add_column :festival_events, :published, :boolean, null: false, default: false
    add_column :festival_events, :visible_facts, :string, array: true, null: false, default: []

    MigrationFestivalEvent.reset_column_information
    taken = []
    MigrationFestivalEvent.find_each do |event|
      slug = event.name.to_s.parameterize.presence || "festival"
      slug = "#{slug}-#{event.id}" if taken.include?(slug)
      taken << slug
      event.update_columns(slug: slug)
    end

    change_column_null :festival_events, :slug, false
    add_index :festival_events, :slug, unique: true
  end

  def down
    remove_index :festival_events, :slug
    remove_column :festival_events, :visible_facts
    remove_column :festival_events, :published
    remove_column :festival_events, :slug
  end
end
