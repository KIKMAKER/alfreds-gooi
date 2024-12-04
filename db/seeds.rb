# USERS & SUBSCRIPTIONS
require 'csv'

puts "Clearing DB"
puts "1"
Collection.destroy_all
puts "2"
Subscription.destroy_all
puts "4"
DriversDay.destroy_all
puts "3"
User.destroy_all
puts "DB Clear with collections"


puts "Uploading users and subscriptions from CSV"

@import_csv = Rails.root.join('db', './users_and_subscribers20240710.csv')

def import_users_from_csv
  CSV.foreach(@import_csv, headers: :first_row) do |row|
    puts "importing a user"
    new_user = User.create!(
      first_name: row[0], last_name: row[1], email: row[2], phone_number: row[4],
      password: "password", role: "customer"
    )
    puts "importing subscription"
    new_subscription = Subscription.new(
      street_address: row[5], plan: row[6], duration: row[7], start_date: row[8], suburb: row[10], customer_id: row[13]
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
kiki = User.create!(first_name: "Kiki", last_name: "Kenn", email: "gooi@gooi.com", password: "password", role: "admin", phone_number: "+27836353126")

puts "Creating Alfred"
alfred = User.create!(
  first_name: "Alfred", last_name: "Mbonjwa", email: "driver@gooi.com", password: "password", role: "driver", phone_number: "+27785325513"
)

puts "Seed file complete with"
puts "#{Subscription.where(collection_day: 2).count} subscriptions for Tuesday"
puts "#{Subscription.where(collection_day: 3).count} subscriptions for Wednesday"

puts "Seed complete."

## PRODUCTS


puts "Clearing db of products"
Product.destroy_all

puts "Creating starter kits"


Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket and first roll of compostable bin liners", price: 200)
Product.create(title: "XL Starter Kit", description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners", price: 300)
starter_kits = Product.count

puts "#{starter_kits} starter kits created"

puts "Creating standard subs"

Product.create(title: "Standard 1 month subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar month", price: 260)
Product.create(title: "Standard 3 month subscription", description: "Weekly collection of up to 10L your kitchen waste for three calendar months (R220pm)", price: 660)
Product.create(title: "Standard 6 month subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 1080)
Product.create(title: "Standard 6 month OG subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 720)

standard_subs = Product.count - starter_kits
puts "#{standard_subs} standard subscriptions created"

puts "Creating XL subs"

Product.create(title: "XL 1 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for one calendar month", price: 300)
Product.create(title: "XL 3 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for three calendar months (R270pm)", price: 810)
Product.create(title: "XL 6 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for six calendar months (R240pm)", price: 1440)

xl_subs = Product.count - starter_kits - standard_subs
puts "#{xl_subs} XL subscriptions created"

puts "Creating additional stock"
Product.create(title: "Compost bin bags", description: "Bonnie Bio garden compostable bin bags (20 bags per roll)", price: 90)
Product.create(title: "Soil for Life Compost", description: "5ks of soil for life potting soil", price: 80)

additional_products = Product.count - starter_kits - standard_subs - xl_subs
puts "#{additional_products} additional products created"


puts "A total of #{Product.count} products have been seeded to the DB."


# HOLIDAY DATES

# a method that sets random past holiday start and end dates for all subscriptions
def set_random_holidays
   subscriptions = Subscription.all.sample(20)
   subscriptions.each do |subscription|
    subscription.update!(holiday_start: Date.yesterday - rand(1..3), holiday_end: Date.tomorrow + rand(1..15))
    puts "#{subscription.user.first_name} has a holiday from #{subscription.holiday_start.strftime('%A, %b %d')} to #{subscription.holiday_end.strftime('%A, %b %d')}"
   end
end

set_random_holidays


# EMERGENCY SEEDS MADE BY CHAT

# db/seeds.rb

# require 'faker'

# # Clear existing data
# Collection.delete_all
# Contact.delete_all
# DriversDay.delete_all
# InvoiceItem.delete_all
# Invoice.delete_all
# Payment.delete_all
# Product.delete_all
# Subscription.delete_all
# # Testimonial.delete_all
# User.delete_all

# # Constants
# NUM_USERS = 20
# NUM_SUBSCRIPTIONS = 20
# NUM_PRODUCTS = 5
# NUM_COLLECTIONS = 30
# NUM_DRIVERS_DAYS = 6
# NUM_INVOICES = 10
# NUM_PAYMENTS = 10
# # NUM_TESTIMONIALS = 5
# NUM_CONTACTS = 2
# SUBURBS = ["Bakoven", "Bantry Bay", "Cape Town", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap (Malay Quarter)", "Devil's Peak Estate", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "Lower Vrede (District Six)", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Walmer Estate (District Six)", "Woodstock (including Upper Woodstock)", "Zonnebloem (District Six)", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kenwyn", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Observatory", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "SouthField", "Steenberg", "Tokai", "Witteboomen", "Wynberg", "Capri Village", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze

# ADDRESSES = [
#   "10 Belmont Road, Cape Town, Western Cape 7700, South Africa",
#   "46 Campground Road, Cape Town, Western Cape 7700, South Africa",
#   "12 Old Farm Road, Cape Town, Western Cape 7700, South Africa",
#   "7 Rouwkoop Avenue, Cape Town, Western Cape 7700, South Africa",
#   "5 Highstead Road, Cape Town, Western Cape 7700, South Africa",
#   "10 Orchard Heights, Cape Town, Western Cape 7700, South Africa",
#   "92 Kildare Road, Cape Town, Western Cape 7700, South Africa",
#   "3 Herschel Close, Cape Town, Western Cape 7708, South Africa",
#   "34 Miller Road, Cape Town, Western Cape 7708, South Africa",
#   "41 Saint Leger Road, Cape Town, Western Cape 7708, South Africa",
#   "13 Prince's Road, Cape Town, Western Cape 7708, South Africa",
#   "13 Goldbourne Road, Kenilworth, Cape Town, 7708",
#   "3 Devon Street, Cape Town, Western Cape 7708, South Africa",
#   "8 Devon Street, Cape Town, Western Cape 7708, South Africa",
#   "1 Gordon Road, Cape Town, Western Cape 7708, South Africa",
#   "21 East Lake Drive, Muizenberg, Western Cape 7945, South Africa",
#   "2 Hastings Road, Muizenberg, Western Cape 7945, South Africa",
#   "7 Royal Road, Muizenberg, Western Cape 7945, South Africa",
#   "29 Atlantic Road, Muizenberg, Western Cape 7945, South Africa",
#   "272 Main Road, Muizenberg, Western Cape 7945, South Africa",
#   "4 Norman Road, Cape Town, Western Cape 7975, South Africa",
#   "51 Clovelly Road, Fish Hoek, Western Cape 7975, South Africa",
#   "1 Ivanhoe Road, Fish Hoek, Western Cape 7975, South Africa",
#   "99 Main Road, Fish Hoek, Western Cape 7975, South Africa",
#   "8 Ladan Road, Cape Town, Western Cape 7975, South Africa",
#   "9 Loch Road, Fish Hoek, Western Cape 7975, South Africa",
#   "9 Gill Road, Muizenberg, Western Cape 7945, South Africa",
#   "5a Verwood Road, Muizenberg, Western Cape 7945, South Africa",
#   "3 Suffolk Road, Muizenberg, Western Cape 7945, South Africa",
#   "Brounger Road, Cape Town, Western Cape 7708, South Africa"
# ]


# # Create users
# users = Array.new(NUM_USERS) do
#   User.create!(
#     first_name: Faker::Name.first_name,
#     last_name: Faker::Name.last_name,
#     phone_number: '+27821234567',
#     email: Faker::Internet.email,
#     password: 'password',
#     role: [0, 1, 2].sample
#   )
# end

# puts "Creating You"
# kiki = User.create!(first_name: "Kiki", last_name: "Kenn", email: "gooi@gooi.com", password: "password", role: "admin", phone_number: "+27836353126")

# puts "Creating Alfred"
# alfred = User.create!(
#   first_name: "Alfred", last_name: "Mbonjwa", email: "driver@gooi.com", password: "password", role: "driver", phone_number: "+27785325513"
# )

# # Create subscriptions
# subscriptions = Array.new(NUM_SUBSCRIPTIONS) do
#   Subscription.create!(
#     customer_id: Faker::Alphanumeric.alphanumeric(number: 10),
#     access_code: Faker::Alphanumeric.alphanumeric(number: 10),
#     street_address: ADDRESSES.sample,
#     suburb: SUBURBS.sample,
#     duration: [1, 3, 6, 12].sample,
#     start_date: Faker::Date.backward(days: 30),
#     collection_day: rand(4..6),
#     plan: rand(0..2),
#     user: users.sample
#   )
# end

## PRODUCTS

# products = []
# puts "Clearing db of products"
# Product.destroy_all

# puts "Creating starter kits"


# products << Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket and first roll of compostable bin liners", price: 200)
# products << Product.create(title: "XL Starter Kit", description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners", price: 300)
# starter_kits = Product.count

# puts "#{starter_kits} starter kits created"

# puts "Creating standard subs"

# products << Product.create(title: "Standard 1 month subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar month", price: 260)
# products << Product.create(title: "Standard 3 month subscription", description: "Weekly collection of up to 10L your kitchen waste for three calendar months (R220pm)", price: 660)
# products << Product.create(title: "Standard 6 month subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 1080)

# standard_subs = Product.count - starter_kits
# puts "#{standard_subs} standard subscriptions created"

# puts "Creating XL subs"

# products << Product.create(title: "XL 1 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for one calendar month", price: 300)
# products << Product.create(title: "XL 3 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for three calendar months (R270pm)", price: 810)
# products << Product.create(title: "XL 6 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for six calendar months (R240pm)", price: 1440)

# xl_subs = Product.count - starter_kits - standard_subs
# puts "#{xl_subs} XL subscriptions created"

# puts "Creating additional stock"
# products << Product.create(title: "Compost bin bags", description: "Bonnie Bio garden compostable bin bags (20 bags per roll)", price: 90)
# products << Product.create(title: "Soil for Life Compost", description: "5ks of soil for life potting soil", price: 80)

# additional_products = Product.count - starter_kits - standard_subs - xl_subs
# puts "#{additional_products} additional products created"


# puts "A total of #{Product.count} products have been seeded to the DB."

# # Create invoices
# invoices = Array.new(NUM_INVOICES) do
#   Invoice.create!(
#     issued_date: Date.today,
#     due_date: Date.today + 30,
#     number: rand(1000..9999),
#     total_amount: Faker::Commerce.price(range: 100..1000),
#     paid: [true, false].sample,
#     subscription: subscriptions.sample
#   )
# end

# # Create invoice items
# invoices.each do |invoice|
#   InvoiceItem.create!(
#     invoice: invoice,
#     product: products.sample,
#     quantity: rand(1..10),
#     amount: Faker::Commerce.price
#   )
# end

# # Create payments
# payments = Array.new(NUM_PAYMENTS) do
#   Payment.create!(
#     snapscan_id: rand(1000..9999),
#     status: ['completed', 'pending', 'failed'].sample,
#     total_amount: rand(100..1000),
#     tip_amount: rand(10..100),
#     fee_amount: rand(5..50),
#     settle_amount: rand(50..900),
#     date: Faker::Date.backward(days: 30),
#     user_reference: Faker::Alphanumeric.alphanumeric(number: 10),
#     merchant_reference: Faker::Alphanumeric.alphanumeric(number: 10),
#     user: users.sample
#   )
# end

# # Create driver days
# drivers_days = Array.new(NUM_DRIVERS_DAYS) do |i|
#   DriversDay.create!(
#     start_time: Date.today + i,
#     end_time: Date.today + i + 1,
#     note: Faker::Lorem.sentence,
#     user: users.find { |user| user.role == "driver" },
#     total_buckets: rand(5..20),
#     date: Date.today + i,
#     sfl_time: Date.today + i + 2,
#     start_kms: rand(100..200),
#     end_kms: rand(200..300),
#     message_from_alfred: Faker::Lorem.sentence
#   )
# end

# # Create collections
# dates = (Date.today..Date.today + 3).to_a
# collections = Array.new(NUM_COLLECTIONS) do |i|
#   date = dates.sample
#   Collection.create!(
#     time: date,
#     kiki_note: Faker::Lorem.sentence,
#     alfred_message: Faker::Lorem.sentence,
#     bags: rand(1..3),
#     subscription: subscriptions.sample,
#     # is_done: [true, false].sample,
#     skip: [true, false].sample,
#     needs_bags: rand(0..5),
#     date: Date.today + i % 4,
#     new_customer: [true, false].sample,
#     buckets: rand(0.0..5.0).round(2),
#     dropped_off_buckets: rand(0..5),
#     soil_bag: rand(0..3),
#     order: rand(0..3),
#     drivers_day: drivers_days.find { |drivers_day| drivers_day.date == date }
#   )
# end

# # # Create testimonials
# # testimonials = Array.new(NUM_TESTIMONIALS) do
# #   Testimonial.create!(
# #     content: Faker::Lorem.paragraph,
# #     ranking: rand(1..5),
# #     user: users.sample
# #   )
# # end

# # Create contacts
# contacts = Array.new(NUM_CONTACTS) do
#   Contact.create!(
#     subscription: subscriptions.sample,
#     name: Faker::Name.name,
#     phone_number: '+27821234567',
#     email: Faker::Internet.email,
#     is_available: [true, false].sample
#   )
# end

puts "Seed data created successfully!"
