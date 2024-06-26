puts "Clearing db of products"
Products.destroy_all

Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket and first roll of compostable bin liners", price: 200)
Product.create(title: "Standard Starter Kit", description: "Countertop Gooi bucket, XL bucket, and first roll of compostable bin liners", price: 300)

puts "#{Product.count} starter kits created"
