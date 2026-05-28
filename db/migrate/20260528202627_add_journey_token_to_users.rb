class AddJourneyTokenToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :journey_token, :string
    add_index :users, :journey_token, unique: true

    # Backfill all existing users with a unique token
    User.find_each do |user|
      user.update_column(:journey_token, SecureRandom.alphanumeric(8).downcase)
    end
  end
end
