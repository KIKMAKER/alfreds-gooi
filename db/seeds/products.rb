puts "Clearing db of products"
Products.destroy_all

puts "Creating starter kits"


Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket and first roll of compostable bin liners", price: 200)
Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners", price: 300)
starter_kits = Product.count

puts "#{starter_kits} starter kits created"

puts "Creating standard subs"

Product.create(title: "Standard 1 month subscription", description: "Weekly collection of up to 10L your kitchen waste for one calendar month", price: 260)
Product.create(title: "Standard 3 month subscription", description: "Weekly collection of up to 10L your kitchen waste for three calendar months (R220pm)", price: 660)
Product.create(title: "Standard 6 month subscription", description: "Weekly collection of up to 10L your kitchen waste for six calendar months (R180pm)", price: 1080)

standard_subs = Product.count - starter_kits
puts "#{standard_subs} starter kits created"

puts "Creating XL subs"

Product.create(title: "XL 1 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for one calendar month", price: 300)
Product.create(title: "XL 3 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for three calendar months (R270pm)", price: 810)
Product.create(title: "XL 6 month subscription", description: "Weekly collection of up to 20L of your kitchen waste for six calendar months (R240pm)", price: 1440)

xl_subs = Product.count - starter_kits - standard_subs
puts "#{xl_subs} starter kits created"

puts "Creating additional stock"
Product.create(title: "Compost bin bags", description: "Bonnie Bio garden compostable bin bags (20 bags per roll)", price: 90)
Product.create(title: "Soil for Life Compost", description: "5ks of soil for life potting soil", price: 80)

additional_products = Product.count - starter_kits - standard_subs - xl_subs
puts "#{additional_products} starter kits created"


puts "A total of #{Product.count} products have been seeded to the DB."
