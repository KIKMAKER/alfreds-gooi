class CreateReferrals < ActiveRecord::Migration[7.0]
  def change
    create_table :referrals do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :users }
      t.references :referee, null: false, foreign_key: { to_table: :users }
      t.references :subscription, foreign_key: true

      t.timestamps
    end
  end
end
