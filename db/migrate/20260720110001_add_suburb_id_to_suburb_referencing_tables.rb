class AddSuburbIdToSuburbReferencingTables < ActiveRecord::Migration[7.2]
  def change
    add_reference :subscriptions, :suburb, null: true, foreign_key: true
    add_reference :drop_off_sites, :suburb, null: true, foreign_key: true
    add_reference :business_profiles, :suburb, null: true, foreign_key: true
    add_reference :interests, :suburb, null: true, foreign_key: true
  end
end
