class ChangeStartKmsAndEndKmsToInteger < ActiveRecord::Migration[7.0]
  def change
    change_column :drivers_days, :start_kms, :integer
    change_column :drivers_days, :end_kms, :integer
  end
end
