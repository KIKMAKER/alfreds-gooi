class AddUniqueIndexToReferrals < ActiveRecord::Migration[7.2]
  def change
    add_index :referrals, %i[referee_id referrer_id], unique: true
  end
end
