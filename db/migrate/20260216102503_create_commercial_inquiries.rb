class CreateCommercialInquiries < ActiveRecord::Migration[7.2]
  def change
    create_table :commercial_inquiries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :business_name
      t.text :business_address
      t.integer :estimated_buckets
      t.integer :preferred_duration
      t.string :collection_frequency
      t.text :additional_notes
      t.string :status, default: 'pending', null: false

      t.timestamps
    end
  end
end
