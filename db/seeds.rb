# Add the seed actions for the production environment to this file.

puts "Seed running."

require 'csv'

puts "Clearing DB"
puts "1"
Subscription.destroy_all
puts "2"
User.destroy_all
puts "DB Clear apart from collections"

puts "Uploading users and subscriptions from CSV"

@import_csv = Rails.root.join('db', './users_and_subscribers_dec_final.csv')

def import_users_from_csv
  CSV.foreach(@import_csv, headers: :first_row) do |row|
    puts "importing a user"
    new_user = User.create!(
      first_name: row[0], last_name: row[1], email: row[2], phone_number: row[3],
      password: "password", role: "customer"
    )
    puts "importing subscription"
    new_subscription = Subscription.new(
      street_address: row[4], plan: row[5], duration: row[6], start_date: row[7],
      status: "active", suburb: row[9], collection_day: row[10].to_i, customer_id: row[13],
      holiday_start: row[11], holiday_end: row[12]
    )
    new_subscription.user = new_user
    new_subscription.save!
    p "#{new_subscription.collection_day}"
  end
end

import_users_from_csv

puts "#{User.count} users added"

puts "#{Subscription.count} subscriptions added"

puts "Creating You"
kiki = User.create!(first_name: "Kiki", last_name: "Kenn", email: "gooi@gooi.com", password: "password", role: "admin")

puts "Creating Alfred"
alfred = User.create!(
  first_name: "Alfred", last_name: "Mbonjwa", email: "driver@gooi.com", password: "password", role: "driver"
)

puts "Seed file complete with"
puts "#{Subscription.where(collection_day: 2).count} subscriptions for Tuesday"
puts "#{Subscription.where(collection_day: 3).count} subscriptions for Wednesday"

puts "Seed complete."
