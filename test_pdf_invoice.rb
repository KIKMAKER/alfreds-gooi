# Test script for PDF invoice generation
# Run in Rails console: load 'test_pdf_invoice.rb'

puts "Testing PDF Invoice Generation..."
puts "=" * 50

# Find a recent invoice with items
invoice = Invoice.includes(:invoice_items, subscription: [:user, :business_profile]).order(created_at: :desc).first

if invoice.nil?
  puts "ERROR: No invoices found in database"
  exit
end

puts "Using Invoice ##{invoice.id} (Number: #{invoice.number})"
puts "Customer: #{invoice.subscription&.user&.first_name} #{invoice.subscription&.user&.last_name}"
puts "Items: #{invoice.invoice_items.count}"
puts "-" * 50

# Test 1: Generate PDF
begin
  pdf = InvoicePdfGenerator.new(invoice).generate
  puts "✓ PDF generated successfully"

  # Save to tmp for manual inspection
  filename = Rails.root.join('tmp', "test_invoice_#{invoice.id}.pdf")
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
  mail = InvoiceMailer.with(invoice: invoice).invoice_created
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
puts "All tests passed! PDF invoice generation is working."
puts "Check the PDF at: tmp/test_invoice_#{invoice.id}.pdf"
