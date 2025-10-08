class RemoveDropOffSiteFromUsers < ActiveRecord::Migration[7.2]
  def change
    remove_reference :users, :drop_off_site, foreign_key: true
  end
end
