class AddUserToDropOffSites < ActiveRecord::Migration[7.2]
  def change
    add_reference :drop_off_sites, :user, null: true, foreign_key: true
  end
end
