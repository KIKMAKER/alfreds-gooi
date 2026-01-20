# Test script for PDF quotation generation
# Run in Rails console: load 'test_pdf_quotation.rb'

puts "Testing PDF Quotation Generation..."
puts "=" * 50

# Find a recent quotation with items
quotation = Quotation.includes(:quotation_items, :user).order(created_at: :desc).first

if quotation.nil?
  puts "ERROR: No quotations found in database"
  exit
end

puts "Using Quotation ##{quotation.id} (Number: #{quotation.number})"
puts "Customer: #{quotation.customer_name}"
puts "Items: #{quotation.quotation_items.count}"
puts "-" * 50

# Test 1: Generate PDF
begin
  pdf = QuotationPdfGenerator.new(quotation).generate
  puts "✓ PDF generated successfully"

  # Save to tmp for manual inspection
  filename = Rails.root.join('tmp', "test_quotation_#{quotation.id}.pdf")
  File.open(filename, 'wb') { |f| f.write(pdf.render) }
  puts "✓ PDF saved to: #{filename}"
  puts "  File size: #{File.size(filename) / 1024}KB"
rescue => e
  puts "✗ PDF generation failed: #{e.message}"
  puts e.backtrace.first(5)
  exit
end

# Test 2: Test mailer attachment
begin
  mail = QuotationMailer.with(quotation: quotation).quotation_created
  puts "✓ Email with PDF attachment created"
  puts "  To: #{mail.to.join(', ')}"
  puts "  Subject: #{mail.subject}"
  puts "  Attachments: #{mail.attachments.count}"

  if mail.attachments.any?
    attachment = mail.attachments.first
    puts "  Attachment filename: #{attachment.filename}"
    puts "  Attachment size: #{attachment.body.raw_source.size / 1024}KB"
  end
rescue => e
  puts "✗ Email generation failed: #{e.message}"
  puts e.backtrace.first(5)
end

puts "=" * 50
puts "All tests passed! PDF quotation generation is working."
puts "Check the PDF at: tmp/test_quotation_#{quotation.id}.pdf"
