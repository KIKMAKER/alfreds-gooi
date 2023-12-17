class ChangeStartKmsAndEndKmsToInteger < ActiveRecord::Migration[7.0]
  def up
    # Convert start_kms and end_kms to integer, using explicit casting
    change_column :drivers_days, :start_kms, 'integer USING CAST(start_kms AS integer)'
    change_column :drivers_days, :end_kms, 'integer USING CAST(end_kms AS integer)'
  end

  def down
    # Convert back to datetime if you roll back this migration
    change_column :drivers_days, :start_kms, :datetime
    change_column :drivers_days, :end_kms, :datetime
  end
end
