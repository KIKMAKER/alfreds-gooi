class AddReferralCodeToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :referral_code, :string
  end
end
