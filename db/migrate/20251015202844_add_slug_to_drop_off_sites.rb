class AddSlugToDropOffSites < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_sites, :slug, :string
    add_index :drop_off_sites, :slug, unique: true
  end
end
