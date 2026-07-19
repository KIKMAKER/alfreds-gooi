class CreateCostModels < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_models do |t|
      # People
      t.decimal :founder_salary, precision: 10, scale: 2, null: false, default: 0
      t.decimal :driver_salary,  precision: 10, scale: 2, null: false, default: 0

      # Fixed costs per bakkie (multiplied by num_bakkies)
      t.decimal :depreciation, precision: 10, scale: 2, null: false, default: 0
      t.decimal :maintenance,  precision: 10, scale: 2, null: false, default: 0
      t.decimal :hosting,      precision: 10, scale: 2, null: false, default: 0
      t.decimal :data_comms,   precision: 10, scale: 2, null: false, default: 0
      t.decimal :bank_fees,    precision: 10, scale: 2, null: false, default: 0
      t.decimal :licence,      precision: 10, scale: 2, null: false, default: 0

      # Variable costs
      t.decimal :fuel_per_route_day,   precision: 10, scale: 2, null: false, default: 0
      t.integer :route_days_per_month, null: false, default: 0
      t.decimal :marketing, precision: 10, scale: 2, null: false, default: 0
      t.decimal :supplies,  precision: 10, scale: 2, null: false, default: 0
      t.decimal :other,     precision: 10, scale: 2, null: false, default: 0

      t.integer :num_bakkies, null: false, default: 1

      # Volume assumptions used for the pricing floor
      t.decimal :target_monthly_litres, precision: 12, scale: 2, null: false, default: 0
      t.decimal :minimum_margin_pct, precision: 5, scale: 4, null: false, default: 0.25

      t.timestamps
    end
  end
end
