class ChangeStartKmsAndEndKmsToInteger < ActiveRecord::Migration[7.0]
  def up
    # Remove the old columns
    remove_column :drivers_days, :start_kms
    remove_column :drivers_days, :end_kms

    # Add new integer columns
    add_column :drivers_days, :start_kms, :integer
    add_column :drivers_days, :end_kms, :integer
  end

  def down
    # Remove the integer columns
    remove_column :drivers_days, :start_kms
    remove_column :drivers_days, :end_kms

    # Add back the datetime columns
    add_column :drivers_days, :start_kms, :datetime
    add_column :drivers_days, :end_kms, :datetime
  end
end
