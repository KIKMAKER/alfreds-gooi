class SeedEventProducts < ActiveRecord::Migration[7.2]
  def up
    [
      {
        title: "Event - Onsite Collection",
        description: "Full bakkie collection service for a single-day event. Covers vehicle, fuel, and collection labour.",
        price: 3500.0
      },
      {
        title: "Event - Processing & Composting Fee",
        description: "Processing and composting of collected organic waste at our composting facility.",
        price: 2500.0
      },
      {
        title: "Event - Onsite Management",
        description: "Dedicated onsite waste management staff to sort, monitor, and manage organic waste streams throughout the event.",
        price: 2500.0
      }
    ].each do |attrs|
      unless Product.exists?(title: attrs[:title])
        Product.create!(attrs.merge(is_active: true, stock: 0))
      end
    end
  end

  def down
    Product.where(title: [
      "Event - Onsite Collection",
      "Event - Processing & Composting Fee",
      "Event - Onsite Management"
    ]).destroy_all
  end
end
