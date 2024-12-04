class AddApartmentUnitNumberToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :apartment_unit_number, :string
  end
end
