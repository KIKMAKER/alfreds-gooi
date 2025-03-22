class CreateDiscountCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :discount_codes do |t|
      t.string :code
      t.integer :discount_cents
      t.datetime :expires_at
      t.integer :usage_limit
      t.integer :used_count
      t.boolean :default, default: false

      t.timestamps
    end
  end
end
