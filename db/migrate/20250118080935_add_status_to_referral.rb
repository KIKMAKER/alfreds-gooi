class AddStatusToReferral < ActiveRecord::Migration[7.0]
  def change
    add_column :referrals, :status, :integer, default: 0
  end
end
