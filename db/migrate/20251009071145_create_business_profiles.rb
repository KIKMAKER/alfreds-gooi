class CreateBusinessProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :business_profiles do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :business_name
      t.string :vat_number
      t.string :contact_person
      t.string :street_address
      t.string :suburb
      t.string :postal_code

      t.timestamps
    end
  end
end
