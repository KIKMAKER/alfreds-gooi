# app/services/invoice_pdf_generator.rb
require 'prawn'
require 'prawn/table'

class InvoicePdfGenerator
  def initialize(invoice)
    @invoice = invoice
    @subscription = invoice.subscription
    @user = @subscription&.user
    @business_profile = @subscription&.business_profile
  end

  def generate
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with branding
      add_header(pdf)

      # Invoice info and customer details
      add_invoice_details(pdf)

      # Invoice items table
      add_items_table(pdf)

      # Payment details
      add_payment_details(pdf)

      # Footer
      add_footer(pdf)
    end
  end

  private

  def add_header(pdf)
    pdf.font 'Helvetica', size: 24, style: :bold
    pdf.text 'GOOI', color: 'F5B11A'
    pdf.move_down 5
    pdf.font 'Helvetica', size: 10
    pdf.text 'compost collections', color: '666666'
    pdf.move_down 20

    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_invoice_details(pdf)
    # Invoice title and number
    pdf.font 'Helvetica', size: 20, style: :bold
    pdf.text "Invoice ##{@invoice.number || @invoice.id}"
    pdf.move_down 20

    # Two column layout for invoice details
    details_data = [
      ['For:', "#{@user&.first_name} #{@user&.last_name}"],
      ['Email:', @user&.email || 'N/A'],
      ['Customer ID:', @subscription&.customer_id || 'N/A'],
      ['Address:', "#{@subscription&.short_address}, #{@subscription&.suburb}"],
      ['Invoice Date:', @invoice.issued_date&.strftime('%e %b %Y') || 'N/A'],
      ['Due Date:', @invoice.paid ? 'PAID' : (@invoice.due_date&.strftime('%e %b %Y') || 'N/A')]
    ]

    # Add business profile if present
    if @business_profile
      details_data << ['Business:', @business_profile.business_name]
      details_data << ['VAT #:', @business_profile.vat_number] if @business_profile.vat_number.present?
      details_data << ['Att:', @business_profile.contact_person] if @business_profile.contact_person.present?
    end

    pdf.font 'Helvetica', size: 10
    pdf.table(details_data,
              column_widths: [100, 400],
              cell_style: {
                borders: [],
                padding: [3, 5]
              }) do |table|
      table.column(0).font_style = :bold
    end

    pdf.move_down 25
  end

  def add_items_table(pdf)
    pdf.font 'Helvetica', size: 12, style: :bold
    pdf.text 'Invoice Items'
    pdf.move_down 10

    # Prepare table data
    table_data = [['Qty', 'Item', 'Amount']]

    @invoice.invoice_items.each do |item|
      description = format_item_description(item)
      amount = "R#{(item.amount * item.quantity).to_i}"
      table_data << [item.quantity.to_i.to_s, description, amount]
    end

    # Add discount codes
    @invoice.invoice_discount_codes.each do |invoice_discount|
      description = "#{invoice_discount.discount_code.code} Discount"
      amount = "-R#{'%.2f' % invoice_discount.discount_amount}"
      table_data << ['1', description, amount]
    end

    # Create table
    pdf.font 'Helvetica', size: 10
    pdf.table(table_data,
              header: true,
              column_widths: [50, 380, 85],
              cell_style: {
                padding: [8, 5],
                borders: [:bottom],
                border_color: 'DDDDDD'
              }) do |table|
      # Header row styling
      table.row(0).font_style = :bold
      table.row(0).background_color = 'F5F5F5'
      table.row(0).borders = [:top, :bottom]
      table.row(0).border_width = 1.5

      # Right align amount column
      table.column(2).align = :right

      # Center align quantity column
      table.column(0).align = :center
    end

    pdf.move_down 15

    # Total
    pdf.font 'Helvetica', size: 14, style: :bold
    pdf.text "Total: R#{@invoice.total_amount.to_i}", align: :right
    pdf.move_down 30
  end

  def format_item_description(item)
    title = item.product.title

    if title.start_with?("Volume Processing per 45L")
      rate_per_bucket = item.product.price
      buckets_per_collection = (item.amount / rate_per_bucket).to_i
      liters_per_collection = buckets_per_collection * 45
      rate_per_liter = item.amount.to_f / liters_per_collection
      "Volume Processing (#{liters_per_collection}L per collection) @ R#{'%.2f' % rate_per_liter}/L"
    elsif title.start_with?("Volume Processing per 25L")
      rate_per_bucket = item.product.price
      buckets_per_collection = (item.amount / rate_per_bucket).to_i
      liters_per_collection = buckets_per_collection * 25
      rate_per_liter = item.amount.to_f / liters_per_collection
      "Volume Processing (#{liters_per_collection}L per collection) @ R#{'%.2f' % rate_per_liter}/L"
    elsif title.start_with?("Commercial Starter Buckets")
      "#{title} @ R#{item.amount.to_i} each"
    elsif title.start_with?("Weekly Collection Service")
      "#{title} @ R#{item.amount.to_i}/month"
    else
      if item.quantity > 1
        "#{title} (R#{item.amount.to_i} each)"
      else
        title
      end
    end
  end

  def add_payment_details(pdf)
    pdf.font 'Helvetica', size: 12, style: :bold
    pdf.text 'Payment Details'
    pdf.move_down 10

    pdf.font 'Helvetica', size: 10

    payment_data = [
      ['Bank:', 'FNB'],
      ['Account Name:', 'Gooi'],
      ['Account Number:', '63066225426'],
      ['Branch Code:', '250655'],
      ['Reference:', "Invoice ##{@invoice.id} - #{@subscription&.customer_id}"]
    ]

    pdf.table(payment_data,
              column_widths: [120, 380],
              cell_style: {
                borders: [],
                padding: [3, 5]
              }) do |table|
      table.column(0).font_style = :bold
    end

    pdf.move_down 10
    pdf.font 'Helvetica', size: 9, style: :italic
    pdf.text 'Please use the reference above when making payment.'
    pdf.move_down 5
    pdf.text 'You can also pay via SnapScan at: https://pos.snapscan.io/qr/8jQ1QVVb'
  end

  def add_footer(pdf)
    pdf.move_down 40
    pdf.stroke_horizontal_rule
    pdf.move_down 10

    pdf.font 'Helvetica', size: 8, style: :italic
    pdf.text 'Thank you for choosing Gooi!', align: :center, color: '666666'
    pdf.text 'Contact us: howzit@gooi.me | www.gooi.me', align: :center, color: '666666'
  end
end
