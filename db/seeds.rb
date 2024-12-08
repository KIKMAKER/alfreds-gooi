require 'csv'

## PRODUCTS
puts "Creating starter kits"

def seed_products(products)
  products.each do |product|
    Product.find_or_create_by!(title: product[:title]) do |p|
      p.description = product[:description]
      p.price = product[:price]
    end
  end
end

starter_kit_products = [
  { title: "Standard Starter Kit", description: "Countertop Gooi bucket and first roll of compostable bin liners", price: 200 },
  { title: "XL Starter Kit", description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners", price: 300 }
]

seed_products(starter_kit_products)
STARTER_KIT = Product.first

starter_kits = Product.where(title: starter_kit_products.map { |p| p[:title] }).count
puts "#{starter_kits} starter kits created"

puts "Creating standard subs"

standard_sub_products = [
  { title: "Standard 1 month subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar month", price: 260 },
  { title: "Standard 3 month subscription", description: "Weekly collection of up to 10L your kitchen waste for three calendar months (R220pm)", price: 660 },
  { title: "Standard 6 month subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 1080 },
  { title: "Standard 6 month OG subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 720 },
  { title: "Standard 1 month OG ad hoc subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar months (R120pm)", price: 120 }
]

seed_products(standard_sub_products)

standard_subs = Product.where(title: standard_sub_products.map { |p| p[:title] }).count
puts "#{standard_subs} standard subscriptions created"

puts "Creating XL subs"

xl_sub_products = [
  { title: "XL 1 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for one calendar month", price: 300 },
  { title: "XL 3 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for three calendar months (R270pm)", price: 810 },
  { title: "XL 6 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for six calendar months (R240pm)", price: 1440 }
]

seed_products(xl_sub_products)

xl_subs = Product.where(title: xl_sub_products.map { |p| p[:title] }).count
puts "#{xl_subs} XL subscriptions created"

puts "Creating additional stock"

additional_stock_products = [
  { title: "Compost bin bags", description: "Bonnie Bio garden compostable bin bags (20 bags per roll)", price: 90 },
  { title: "Soil for Life Compost", description: "5ks of soil for life potting soil", price: 80 }
]

seed_products(additional_stock_products)

puts "Additional stock created"

puts "A total of #{Product.count} products have been seeded to the DB."

# DEV ONLY SEEDS

if Rails.env.development?

  puts "This will clear all data. Are you sure? (y/n)"
  exit unless STDIN.gets.chomp.downcase == "y"

  puts "Clearing DB"

  puts "1"
  InvoiceItem.destroy_all    # Depends on Invoice and Product
  puts "2"
  Collection.destroy_all     # Depends on Subscription and DriversDay
  puts "3"
  # Contact.destroy_all        # Depends on Subscription
  puts "4"
  Payment.destroy_all
  puts "5"
  Invoice.destroy_all        # Depends on Subscription
  puts "6"
  DriversDay.destroy_all     # Depends on User
  puts "7"
  Subscription.destroy_all   # Depends on User
  puts "8"
  User.destroy_all           # Top-level model (referenced by multiple others)
  puts "9"

  puts "DB Clear"

  p STARTER_KIT

  # USERS & SUBSCRIPTIONS **** DEV ENV ONLY***
  puts "Uploading users and subscriptions from CSV"

  @import_csv = Rails.root.join('db', 'LOGS for CSV - export_csv.csv')

  def import_users_from_csv
    CSV.foreach(@import_csv, headers: :first_row) do |row|
      puts "importing a user"
      new_user = User.create!(
        first_name: row[0], last_name: row[1], email: row[2], phone_number: row[3],
        password: "password", role: "customer"
      )
      puts "importing subscription"
      new_subscription = Subscription.new(
        street_address: row[4], plan: row[5], duration: row[6], start_date: row[7], suburb: row[9], customer_id: row[11]
      )
      new_subscription.user = new_user
      new_subscription.save!
      p "#{new_subscription.collection_day}"
    end
  end

  import_users_from_csv

  puts "#{User.count} users added"

  puts "#{Subscription.count} subscriptions added"
  puts "Dev Users and Subs Seed file complete with"
  puts "#{Subscription.where(collection_day: 2).count} subscriptions for Tuesday"
  puts "#{Subscription.where(collection_day: 3).count} subscriptions for Wednesday"
  puts "#{Subscription.where(collection_day: 4).count} subscriptions for Thursday"



  # a method that sets random past holiday start and end dates for all subscriptions
  def set_random_holidays
    subscriptions = Subscription.all.sample(20)
    subscriptions.each do |subscription|
    subscription.update!(holiday_start: Date.yesterday - rand(1..3), holiday_end: Date.tomorrow + rand(1..15))
    puts "#{subscription.user.first_name} has a holiday from #{subscription.holiday_start.strftime('%A, %b %d')} to #{subscription.holiday_end.strftime('%A, %b %d')}"
    end
  end

  puts "setting random holidays"

  set_random_holidays

  # # Create invoices

  puts "Creating invoices"
  invoices = Array.new(Subscription.count) do
    Invoice.create!(
      issued_date: Date.today,
      due_date: Date.today + 30,
      paid: [true, false].sample,
      subscription: Subscription.all.sample
    )
  end

  # # Create invoice items
  invoices.each do |invoice|
    # starter_kit = Product.first
    InvoiceItem.create!(
      invoice: invoice,
      product: STARTER_KIT,
      quantity: 1,
      amount: STARTER_KIT.price
    )
    product = Product.find(STARTER_KIT.id + 4)

    p STARTER_KIT
    p product

    InvoiceItem.create!(
      invoice: invoice,
      product: product,
      quantity: 1,
      amount: product.price
    )
  end
  puts "#{Invoice.count} invoices created with #{InvoiceItem.count} invoice items"

  puts "Creating Alfred"
  alfred = User.find_or_create_by!(email: "driver@gooi.com") do |user|
    user.first_name = "Alfred"
    user.last_name = "Mbonjwa"
    user.password = "password"
    user.role = "driver"
    user.phone_number = "+27785325513"
  end
  puts "Alfred created with user id: #{alfred.id}"

  # # Create driver days

  puts "Creating driver days"
  drivers_days = Array.new(7) do |i|
    dd = DriversDay.create!(
      start_time: Time.now + i,
      end_time: Time.now + i + 1,
      note: "generic note",
      user: User.find_by(role: "driver"),
      total_buckets: rand(5..20),
      date: Date.today + i,
      sfl_time: Date.today + i + 2,
      start_kms: rand(100..200),
      end_kms: rand(200..300),
      message_from_alfred: "generic message from alfred"
    )
    # time_range = dd.start_time.to_datetime.step(dd.end_time.to_datetime, 1.hour).map(&:to_time)
    number_of_subs = Subscription.where(collection_day: dd.date.wday).count
    if Subscription.where(collection_day: dd.date.wday).any?
      col = Collection.create!(
        time: dd.start_time + (i/3),
        kiki_note: "generic note from kiki",
        alfred_message: "another note from alfred",

        subscription: Subscription.where(collection_day: dd.date.wday).sample,
        is_done: [true, true, true, true, false].sample,
        skip: [true, false, false, false, false].sample,
        needs_bags: rand(0..1),
        date: dd.date,
        new_customer: [true, false, false, false, false, false].sample,
        soil_bag: rand(0..1),
        drivers_day: dd
      )
      if col.subscription.XL?
        col.update!(buckets: rand(0.0..5.0).round(2))
      elsif col.subscription.user.drop_off?
        col.update!(dropped_off_buckets: rand(0..5))
      else
        col.update!(bags: rand(1..3))
      end
    end

  end

end

# ADMIN + DRIVER
puts "Creating You"
kiki = User.find_or_create_by!(email: "gooi@gooi.com") do |user|
  user.first_name = "Kiki"
  user.last_name = "Kenn"
  user.password = "password"
  user.role = "admin"
  user.phone_number = "+27836353126"
end

puts "Creating Alfred"
alfred = User.find_or_create_by!(email: "driver@gooi.com") do |user|
  user.first_name = "Alfred"
  user.last_name = "Mbonjwa"
  user.password = "password"
  user.role = "driver"
  user.phone_number = "+27785325513"
end

puts "Seed data created successfully!"
