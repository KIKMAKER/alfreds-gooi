puts "\n--- Seeding quotations ---"

# Commercial quote products must exist
weekly_product = Product.find_by(title: "Weekly collection (6-month rate @ R220pm)")
vol_25_product = Product.find_by(title: "Volume Processing per 25L (Premium 6-month rate)")
vol_45_product = Product.find_by(title: "Volume Processing per 45L (Premium 6-month rate)")

unless weekly_product && vol_45_product
  puts "  ✗ Quote products not found — run 'products' seed first."
  return
end

# Helper to build quote items and set total_amount
def build_quote_items(quotation, items)
  items.each do |item|
    QuotationItem.create!(
      quotation: quotation,
      product:   item[:product],
      quantity:  item[:quantity],
      amount:    item[:product].price
    )
  end
  quotation.calculate_total
end

# 1. DRAFT — prospect inquiry, not yet sent
draft = Quotation.create!(
  prospect_name:    "Oranjezicht City Farm Market",
  prospect_email:   "info@ozcf.co.za",
  prospect_company: "OZCF Market",
  prospect_phone:   "+27214615611",
  created_date:     Date.today - 3.days,
  expires_at:       Date.today + 27.days,
  status:           :draft,
  quote_type:       :subscription,
  duration_months:  6,
  collections_per_week: 1,
  buckets_per_collection: 2
)
build_quote_items(draft, [
  { product: weekly_product, quantity: 1 },
  { product: vol_45_product, quantity: 2 }
])
puts "  ✓ Draft — Oranjezicht City Farm Market (R#{draft.total_amount})"

# 2. SENT — prospect awaiting response
sent = Quotation.create!(
  prospect_name:    "Neighbourgoods Market Cafe",
  prospect_email:   "hello@neighbourgoods.net",
  prospect_company: "Neighbourgoods Market",
  created_date:     Date.today - 10.days,
  expires_at:       Date.today + 20.days,
  status:           :sent,
  quote_type:       :subscription,
  duration_months:  6,
  collections_per_week: 2,
  buckets_per_collection: 2
)
build_quote_items(sent, [
  { product: weekly_product, quantity: 2 },
  { product: vol_45_product, quantity: 4 }
])
puts "  ✓ Sent — Neighbourgoods Market Cafe (R#{sent.total_amount}, 2 collections/week)"

# 3. ACCEPTED — linked to a real user if one exists, otherwise prospect
#    Pick the first active customer with a known subscription; fall back gracefully
accepted_user = User.where(role: :customer).joins(:subscriptions)
                    .where(subscriptions: { status: :active })
                    .order("RANDOM()").first

accepted_attrs = {
  created_date:     Date.today - 45.days,
  expires_at:       Date.today + 15.days,
  status:           :accepted,
  quote_type:       :subscription,
  duration_months:  6,
  collections_per_week: 1,
  buckets_per_collection: 2
}

if accepted_user
  accepted_attrs[:user] = accepted_user
else
  accepted_attrs.merge!(
    prospect_name:    "The Woodstock Bakery",
    prospect_email:   "orders@woodstockbakery.co.za",
    prospect_company: "Woodstock Bakery"
  )
end

accepted = Quotation.create!(accepted_attrs)
build_quote_items(accepted, [
  { product: weekly_product, quantity: 1 },
  { product: vol_25_product, quantity: 2 }
])
label = accepted_user ? "#{accepted_user.first_name} #{accepted_user.last_name}" : "The Woodstock Bakery"
puts "  ✓ Accepted — #{label} (R#{accepted.total_amount})"

# 4. REJECTED — prospect who declined
rejected = Quotation.create!(
  prospect_name:    "Cape Quarter Lifestyle Village",
  prospect_email:   "management@capequarter.co.za",
  prospect_company: "Cape Quarter",
  created_date:     Date.today - 30.days,
  expires_at:       Date.today + 0.days,
  status:           :rejected,
  quote_type:       :subscription,
  duration_months:  12,
  collections_per_week: 3,
  buckets_per_collection: 2
)
build_quote_items(rejected, [
  { product: weekly_product, quantity: 3 },
  { product: vol_45_product, quantity: 6 }
])
puts "  ✓ Rejected — Cape Quarter Lifestyle Village (R#{rejected.total_amount})"

# 5. EXPIRED — sent 3 months ago, never responded
expired = Quotation.create!(
  prospect_name:    "Truth Coffee Collective",
  prospect_email:   "hello@truthcoffee.com",
  prospect_company: "Truth Coffee",
  notes:            "Very interested initially, went quiet after first follow-up.",
  created_date:     Date.today - 90.days,
  expires_at:       Date.today - 60.days,
  status:           :expired,
  quote_type:       :subscription,
  duration_months:  6,
  collections_per_week: 1,
  buckets_per_collection: 1
)
build_quote_items(expired, [
  { product: weekly_product, quantity: 1 },
  { product: vol_25_product, quantity: 1 }
])
puts "  ✓ Expired — Truth Coffee Collective (sent #{expired.created_date.strftime('%d %b %Y')})"

puts "\n  #{Quotation.count} quotations seeded"
puts "  #{Quotation.group(:status).count.map { |s, c| "#{c} #{s}" }.join(', ')}"
