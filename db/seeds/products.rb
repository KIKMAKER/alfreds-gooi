puts "\n--- Seeding products ---"

def seed_products(products)
  products.each do |attrs|
    p = Product.find_or_initialize_by(title: attrs[:title])
    p.assign_attributes(attrs)
    p.save!
    puts "  ✓ #{p.title} [#{p.billing_type}]"
  end
end

# ── Starter kits ─────────────────────────────────────────────────────────────

starter_kit_products = [
  { title: "Standard Starter Kit",            description: "Countertop Gooi bucket and first roll of compostable bin liners",                  price: 200,  billing_type: "standard" },
  { title: "XL Starter Kit",                  description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners",      price: 300,  billing_type: "standard" },
  { title: "Commercial Starter Bucket (25L)", description: "25L commercial collection bucket with branding",                                   price: 150,  billing_type: "standard" },
  { title: "Commercial Starter Bucket (45L)", description: "45L commercial collection bucket with branding",                                   price: 210,  billing_type: "standard" },
  { title: "Commercial Starter Bucket (50L)", description: "50L commercial collection drum with branding",                                     price: 850,  billing_type: "standard" }
]
seed_products(starter_kit_products)
puts "#{starter_kit_products.size} starter kits seeded"

# ── Standard subscriptions ───────────────────────────────────────────────────

standard_sub_products = [
  { title: "Standard 1 month subscription",           description: "Weekly collection of up to 10L your kitchen waste for one calendar month",                    price: 260,  billing_type: "invoice_only" },
  { title: "Standard 3 month subscription",           description: "Weekly collection of up to 10L your kitchen waste for three calendar months (R220pm)",        price: 660,  billing_type: "invoice_only" },
  { title: "Standard 6 month subscription",           description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)",          price: 1080, billing_type: "invoice_only" },
  { title: "Standard 12 month subscription",          description: "Weekly collection of up to 10L your kitchen waste for 12 calendar months (R180pm)",           price: 2160, billing_type: "invoice_only" },
  { title: "Standard 6 month OG subscription",        description: "Weekly collection of up to 10L your kitchen waste for six calendar months (OG rate)",        price: 720,  billing_type: "invoice_only" },
  { title: "Standard 1 month OG ad hoc subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar month (OG rate)",         price: 120,  billing_type: "invoice_only" },
  { title: "Referral discount standard 1 month",      description: "You get 15% off and your friend gets a discount on their next subscription too!",             price: -39,  billing_type: "invoice_only" },
  { title: "Referral discount standard 3 month",      description: "You get 15% off and your friend gets a discount on their next subscription too!",             price: -99,  billing_type: "invoice_only" },
  { title: "Referral discount standard 6 month",      description: "You get 15% off and your friend gets a discount on their next subscription too!",             price: -162, billing_type: "invoice_only" }
]
seed_products(standard_sub_products)
puts "#{standard_sub_products.size} standard subscription products seeded"

# ── XL subscriptions ─────────────────────────────────────────────────────────

xl_sub_products = [
  { title: "XL 1 month subscription",      description: "Weekly collection of up to 20L of your kitchen waste for one calendar month",             price: 300,  billing_type: "invoice_only" },
  { title: "XL 3 month subscription",      description: "Weekly collection of up to 20L of your kitchen waste for three calendar months (R270pm)", price: 810,  billing_type: "invoice_only" },
  { title: "XL 6 month subscription",      description: "Weekly collection of up to 20L of your kitchen waste for six calendar months (R240pm)",   price: 1440, billing_type: "invoice_only" },
  { title: "Referral discount XL 1 month", description: "You get 15% off and your friend gets a discount on their next subscription too!",         price: -45,  billing_type: "invoice_only" },
  { title: "Referral discount XL 3 month", description: "You get 15% off and your friend gets a discount on their next subscription too!",         price: -122, billing_type: "invoice_only" },
  { title: "Referral discount XL 6 month", description: "You get 15% off and your friend gets a discount on their next subscription too!",         price: -216, billing_type: "invoice_only" }
]
seed_products(xl_sub_products)
puts "#{xl_sub_products.size} XL subscription products seeded"

# ── Commercial rate-card products (invoice_only) ─────────────────────────────

commercial_invoice_products = [
  { title: "Commercial collection fee (6-month)",  description: "Monthly collection service fee, 6-month contract rate",  price: 220,   billing_type: "invoice_only" },
  { title: "Commercial collection fee (12-month)", description: "Monthly collection service fee, 12-month contract rate", price: 200,   billing_type: "invoice_only" },
  { title: "Commercial collection fee (3-month)",  description: "Monthly collection service fee, 3-month contract rate",  price: 240,   billing_type: "invoice_only" },
  { title: "Commercial volume per 25L bucket",     description: "Volume processing per 25L bucket per collection visit",  price: 85.00, billing_type: "invoice_only" },
  { title: "Commercial volume per 45L bucket",     description: "Volume processing per 45L bucket per collection visit",  price: 76.50, billing_type: "invoice_only" },
  { title: "Commercial volume per 50L bucket",     description: "Volume processing per 50L bucket per collection visit",  price: 85.00, billing_type: "invoice_only" }
]
seed_products(commercial_invoice_products)
puts "#{commercial_invoice_products.size} commercial rate-card products seeded"

# ── Commercial quote-only products ───────────────────────────────────────────

commercial_quote_products = [
  { title: "Weekly collection (6-month rate @ R220pm)",        description: "Full 6-month collection contract per weekly slot (6 × R220)", price: 1320, billing_type: "quote_only" },
  { title: "Volume Processing per 25L (Premium 6-month rate)", description: "Full 6-month volume processing contract per 25L bucket",       price: 300,  billing_type: "quote_only" },
  { title: "Volume Processing per 45L (Premium 6-month rate)", description: "Full 6-month volume processing contract per 45L bucket",       price: 459,  billing_type: "quote_only" }
]
seed_products(commercial_quote_products)
puts "#{commercial_quote_products.size} commercial quote-only products seeded"

# ── Additional stock & misc ───────────────────────────────────────────────────

additional_stock_products = [
  { title: "Compost bin bags",                description: "Bonnie Bio garden compostable bin bags (20 bags per roll)", price: 90,  billing_type: "standard" },
  { title: "Soil for Life Compost",           description: "5kg of Soil for Life potting soil",                        price: 80,  billing_type: "standard" },
  { title: "Referred a friend discount (R50)", description: "Referral reward discount",                                price: -50, billing_type: "invoice_only" },
  { title: "Once-off Collection",             description: "Single kitchen scrap collection",                          price: 400, billing_type: "invoice_only" }
]
seed_products(additional_stock_products)
puts "Additional stock and once-off seeded"

# ── Wire quote → invoice product mappings ────────────────────────────────────

{
  "Weekly collection (6-month rate @ R220pm)"         => "Commercial collection fee (6-month)",
  "Volume Processing per 25L (Premium 6-month rate)"  => "Commercial volume per 25L bucket",
  "Volume Processing per 45L (Premium 6-month rate)"  => "Commercial volume per 45L bucket"
}.each do |quote_title, invoice_title|
  quote_p   = Product.find_by!(title: quote_title)
  invoice_p = Product.find_by!(title: invoice_title)
  quote_p.update!(invoice_product_id: invoice_p.id)
  puts "  ✓ #{quote_title} → #{invoice_title}"
end

puts "\nProduct taxonomy summary:"
Product.group(:billing_type).count.each { |type, count| puts "  #{type}: #{count}" }
puts "Total: #{Product.count} products seeded."
