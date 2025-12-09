class AddStarterKitInstallmentToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :starter_kit_installment, :decimal, precision: 10, scale: 2
  end
end
