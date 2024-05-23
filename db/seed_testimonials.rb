require 'csv'
puts "deleting previous testimonials"
Testimonial.destroy_all
puts "creating testimonials"

file_path = Rails.root.join('db', './gooi_testimonials.csv')
Testimonial.import_from_csv(file_path)

puts "#{Testimonial.count} testimonials successfully created"
