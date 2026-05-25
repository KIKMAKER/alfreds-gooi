require 'csv'

puts "Welcome to the Gooi seed file"
puts ""
puts "  [y]           → full reset + seed everything (dev only)"
puts "  [products]    → re-seed product catalogue (idempotent)"
puts "  [users]       → clear and re-seed users and subscriptions from CSV"
puts "  [collections] → reset all collections to be realistic for today's date"
puts "  [dropoffs]    → re-seed drop-off sites and event history"
puts "  [quotes]      → re-seed quotations in all states"
puts "  [payments]    → re-seed payment records"
puts ""

proceed = STDIN.gets.chomp.downcase

def load_seed(file)
  load Rails.root.join("db/seeds/#{file}.rb")
end

# Stub geocoder so creating subscriptions doesn't make Mapbox API calls
def stub_geocoder!
  require 'geocoder/lookups/test'
  Geocoder.configure(lookup: :test)
  Geocoder::Lookup::Test.set_default_stub([
    { 'coordinates' => [-33.9249, 18.4241], 'address' => 'Cape Town, South Africa' }
  ])
end

# ── Payments ──────────────────────────────────────────────────────────────────

if proceed == "payments"
  puts "Clearing past payments"
  Payment.destroy_all

  payments_data = [
    { "id" => 284, "status" => "error",     "totalAmount" => 27000, "tipAmount" => 0, "feeAmount" => 886,  "settleAmount" => 26114, "date" => "2024-12-14T11:48:19Z", "userReference" => "Amanda Hall",  "merchantReference" => "GFWC142" },
    { "id" => 283, "status" => "completed", "totalAmount" => 9000,  "tipAmount" => 0, "feeAmount" => 295,  "settleAmount" => 8705,  "date" => "2024-12-12T06:30:51Z", "userReference" => "Sara araujo",  "merchantReference" => "GFWC123" },
    { "id" => 282, "status" => "completed", "totalAmount" => 46000, "tipAmount" => 0, "feeAmount" => 1509, "settleAmount" => 44491, "date" => "2024-12-10T17:54:14Z", "userReference" => "Peekay",       "merchantReference" => "GFWC001" },
    { "id" => 281, "status" => "completed", "totalAmount" => 72000, "tipAmount" => 0, "feeAmount" => 2362, "settleAmount" => 69638, "date" => "2024-12-10T09:51:04Z", "userReference" => "Maddy Bazil",  "merchantReference" => "GFWC095" }
  ]

  payments_data.each do |p|
    user = User.find_by(customer_id: p["merchantReference"])
    next unless user
    Payment.create!(
      snapscan_id: p["id"], status: p["status"],
      total_amount: p["totalAmount"], tip_amount: p["tipAmount"],
      fee_amount: p["feeAmount"], settle_amount: p["settleAmount"],
      date: p["date"], user_reference: p["userReference"],
      merchant_reference: p["merchantReference"], user_id: user.id
    )
    puts "  ✓ Payment for #{p["userReference"]}"
  end
  puts "Payments seeded."

# ── Products ──────────────────────────────────────────────────────────────────

elsif proceed == "products"
  load_seed 'products'

# ── Drop-off sites ────────────────────────────────────────────────────────────

elsif proceed == "dropoffs"
  load_seed 'drop_off_sites'

# ── Users + subscriptions ─────────────────────────────────────────────────────

elsif proceed == "users"
  abort "Users seed is for development only." unless Rails.env.development?
  puts "This will clear all users, subscriptions, collections and invoices. Continue? (y/n)"
  exit unless STDIN.gets.chomp.downcase == "y"

  stub_geocoder!

  puts "Clearing user data..."
  [OrderItem, Order, InvoiceItem,
   Collection, Invoice, BusinessProfile, Referral,
   WhatsappMessage, Contact, RevenueRecognition,
   DriversDay, QuotationItem, Quotation, Subscription].each(&:destroy_all)
  User.destroy_all
  puts "Cleared."

  load_seed 'users'

# ── Collections (date-relative reset) ────────────────────────────────────────

elsif proceed == "collections"
  puts "This will clear and regenerate all collection records relative to today. Continue? (y/n)"
  exit unless STDIN.gets.chomp.downcase == "y"
  load_seed 'collections'

# ── Quotations ────────────────────────────────────────────────────────────────

elsif proceed == "quotes"
  puts "This will clear and recreate all quotations. Continue? (y/n)"
  exit unless STDIN.gets.chomp.downcase == "y"
  [QuotationItem, Quotation].each(&:destroy_all)
  load_seed 'quotations'

# ── Full reset ────────────────────────────────────────────────────────────────

elsif proceed == "y"
  abort "Full seed is for development only." unless Rails.env.development?
  puts "This will clear ALL data. Are you sure? (y/n)"
  exit unless STDIN.gets.chomp.downcase == "y"

  stub_geocoder!

  puts "\nClearing DB..."
  [
    OrderItem, Order,
    InvoiceItem,
    Collection,
    Invoice, BusinessProfile,
    Referral,
    Bucket, DropOffEvent,
    DriversDay,
    QuotationItem, Quotation,
    WhatsappMessage, Contact, RevenueRecognition,
    Subscription,
    DropOffSite,
    User,
    Payment, Interest, DiscountCode
  ].each do |model|
    count = model.count
    model.destroy_all
    puts "  Cleared #{model.name} (#{count})" if count > 0
  end
  puts "DB cleared.\n"

  load_seed 'products'
  load_seed 'users'
  load_seed 'drop_off_sites'
  load_seed 'collections'
  load_seed 'quotations'

  puts "\n=== Seed complete ==="
  puts "  Products:       #{Product.count}"
  puts "  Users:          #{User.count} (#{User.where(role: :customer).count} customers)"
  puts "  Subscriptions:  #{Subscription.count}"
  puts "    active:     #{Subscription.where(status: :active).count}"
  puts "    paused:     #{Subscription.where(status: :pause).count}"
  puts "    pending:    #{Subscription.where(status: :pending).count}"
  puts "    completed:  #{Subscription.where(status: :completed).count}"
  puts "  Collections:    #{Collection.count} (#{Collection.where(is_done: true).count} done, #{Collection.where(skip: true).count} skipped)"
  puts "  Driver days:    #{DriversDay.count} (#{DayStatistic.count} with stats)"
  puts "  Drop-off sites: #{DropOffSite.count}"
  puts "  Quotations:     #{Quotation.count}"
  puts "\nAll test account passwords: 'password'"
  puts "  driver@gooi.com  /  gooi@gooi.com"

else
  puts "'#{proceed}' wasn't an option. Run rails db:seed and try again."
end
