class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :collection, null: true, foreign_key: true
      t.string :status, default: 'pending'
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.datetime :delivered_at

      t.timestamps
    end
  end
end
