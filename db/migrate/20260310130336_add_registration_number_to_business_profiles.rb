class AddRegistrationNumberToBusinessProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :business_profiles, :registration_number, :string
  end
end
