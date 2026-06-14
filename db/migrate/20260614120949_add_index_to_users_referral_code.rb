class AddIndexToUsersReferralCode < ActiveRecord::Migration[7.2]
  def change
    add_index :users, :referral_code, unique: true
  end
end
