# # USERS & SUBSCRIPTIONS
# require 'csv'

# puts "Clearing DB"
# puts "1"
# Collection.destroy_all
# puts "2"
# Subscription.destroy_all
# puts "4"
# DriversDay.destroy_all
# puts "3"
# User.destroy_all
# puts "DB Clear with collections"


# puts "Uploading users and subscriptions from CSV"

# @import_csv = Rails.root.join('db', './users_and_subscribers20240710.csv')

# def import_users_from_csv
#   CSV.foreach(@import_csv, headers: :first_row) do |row|
#     puts "importing a user"
#     new_user = User.create!(
#       first_name: row[0], last_name: row[1], email: row[2], phone_number: row[4],
#       password: "password", role: "customer"
#     )
#     puts "importing subscription"
#     new_subscription = Subscription.new(
#       street_address: row[5], plan: row[6], duration: row[7], start_date: row[8], suburb: row[10], customer_id: row[13],
#       holiday_start: row[11], holiday_end: row[12]
#     )
#     new_subscription.user = new_user
#     new_subscription.save!
#     p "#{new_subscription.collection_day}"
#   end
# end

# import_users_from_csv

# puts "#{User.count} users added"

# puts "#{Subscription.count} subscriptions added"

# puts "Creating You"
# kiki = User.create!(first_name: "Kiki", last_name: "Kenn", email: "gooi@gooi.com", password: "password", role: "admin", phone_number: "+27836353126")

# puts "Creating Alfred"
# alfred = User.create!(
#   first_name: "Alfred", last_name: "Mbonjwa", email: "driver@gooi.com", password: "password", role: "driver", phone_number: "+27785325513"
# )

# puts "Seed file complete with"
# puts "#{Subscription.where(collection_day: 2).count} subscriptions for Tuesday"
# puts "#{Subscription.where(collection_day: 3).count} subscriptions for Wednesday"

# puts "Seed complete."

# ## PRODUCTS


# puts "Clearing db of products"
# Product.destroy_all

# puts "Creating starter kits"


# Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket and first roll of compostable bin liners", price: 200)
# Product.create(title: "XL Starter Kit", description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners", price: 300)
# starter_kits = Product.count

# puts "#{starter_kits} starter kits created"

# puts "Creating standard subs"

# Product.create(title: "Standard 1 month subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar month", price: 260)
# Product.create(title: "Standard 3 month subscription", description: "Weekly collection of up to 10L your kitchen waste for three calendar months (R220pm)", price: 660)
# Product.create(title: "Standard 6 month subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 1080)

# standard_subs = Product.count - starter_kits
# puts "#{standard_subs} standard subscriptions created"

# puts "Creating XL subs"

# Product.create(title: "XL 1 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for one calendar month", price: 300)
# Product.create(title: "XL 3 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for three calendar months (R270pm)", price: 810)
# Product.create(title: "XL 6 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for six calendar months (R240pm)", price: 1440)

# xl_subs = Product.count - starter_kits - standard_subs
# puts "#{xl_subs} XL subscriptions created"

# puts "Creating additional stock"
# Product.create(title: "Compost bin bags", description: "Bonnie Bio garden compostable bin bags (20 bags per roll)", price: 90)
# Product.create(title: "Soil for Life Compost", description: "5ks of soil for life potting soil", price: 80)

# additional_products = Product.count - starter_kits - standard_subs - xl_subs
# puts "#{additional_products} additional products created"


# puts "A total of #{Product.count} products have been seeded to the DB."


# HOLIDAY DATES

# a method that sets random past holiday start and end dates for all subscriptions
def set_random_holidays
   subscriptions = Subscription.all.sample(15)
   subscriptions.each do |subscription|
    subscription.update!(holiday_start: Date.yesterday - rand(1..10), holiday_end: Date.tomorrow - rand(1..5))
    puts "#{subscription.user.first_name} has a holiday from #{subscription.holiday_start} to #{subscription.holiday_end}"
   end
end

set_random_holidays
