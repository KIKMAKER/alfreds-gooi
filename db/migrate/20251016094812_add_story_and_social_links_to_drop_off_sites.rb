class AddStoryAndSocialLinksToDropOffSites < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_sites, :story, :text
    add_column :drop_off_sites, :website, :string
    add_column :drop_off_sites, :instagram_handle, :string
    add_column :drop_off_sites, :facebook_url, :string
  end
end
