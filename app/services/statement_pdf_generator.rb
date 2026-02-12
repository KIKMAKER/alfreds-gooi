# app/services/statement_pdf_generator.rb
require 'prawn'
require 'prawn/table'

class StatementPdfGenerator
  def initialize(user)
    @user = user
    @invoices = user.invoices.includes(subscription: :user).order(issued_date: :desc)
    @total_invoiced = @invoices.sum(:total_amount)
    @total_paid = @invoices.where(paid: true).sum(:total_amount)
    @balance_owing = @total_invoiced - @total_paid
  end

  def generate
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with branding
      add_header(pdf)

      # Statement details and customer info
      add_statement_details(pdf)

      # Summary totals
      add_summary_totals(pdf)

      # All invoices table
      add_invoices_table(pdf)

      # Payment details if balance owing
      add_payment_details(pdf) if @balance_owing > 0

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

  def add_statement_details(pdf)
    # Statement title
    pdf.font 'Helvetica', size: 20, style: :bold
    pdf.text "Account Statement"
    pdf.move_down 20

    # Two column layout for statement details
    details_data = [
      ['Account Holder:', "#{@user.first_name} #{@user.last_name}"],
      ['Email:', @user.email || 'N/A'],
      ['Customer ID:', @user.id.to_s],
      ['Statement Date:', Date.today.strftime('%e %B %Y')]
    ]

    pdf.font 'Helvetica', size: 10
    pdf.table(details_data,
              column_widths: [120, 380],
              cell_style: {
                borders: [],
                padding: [3, 5]
              }) do |table|
      table.column(0).font_style = :bold
    end

    pdf.move_down 25
  end

  def add_summary_totals(pdf)
    pdf.font 'Helvetica', size: 12, style: :bold
    pdf.text 'Account Summary'
    pdf.move_down 10

    summary_data = [
      ['Total Invoiced:', "R#{@total_invoiced.to_i}"],
      ['Total Paid:', "R#{@total_paid.to_i}"],
      ['Balance Owing:', "R#{@balance_owing.to_i}"]
    ]

    pdf.font 'Helvetica', size: 10
    pdf.table(summary_data,
              column_widths: [400, 115],
              cell_style: {
                borders: [],
                padding: [5, 5]
              }) do |table|
      table.column(0).font_style = :bold
      table.column(1).align = :right
      table.column(1).font_style = :bold

      # Highlight balance owing
      table.row(2).text_color = @balance_owing > 0 ? 'BC4749' : '108A63'
    end

    pdf.move_down 25
  end

  def add_invoices_table(pdf)
    pdf.font 'Helvetica', size: 12, style: :bold
    pdf.text 'Invoice Details'
    pdf.move_down 10

    # Single table with all invoices
    table_data = [['Inv #', 'Address', 'Plan', 'L/Coll', 'Date', 'Due Date', 'Amount', 'Status']]

    @invoices.each do |invoice|
      subscription = invoice.subscription

      # Calculate L/collection
      liters = case subscription.plan
      when "Standard"
        "10L"
      when "XL"
        "25L"
      when "Commercial"
        "#{subscription.bucket_size * subscription.buckets_per_collection}L"
      else
        "N/A"
      end

      # Truncate address if too long
      address = "#{subscription.short_address}, #{subscription.suburb}"
      address = address.length > 35 ? "#{address[0..32]}..." : address

      table_data << [
        "##{invoice.number || invoice.id}",
        address,
        subscription.plan,
        liters,
        invoice.issued_date&.strftime('%e %b') || 'N/A',
        invoice.due_date&.strftime('%e %b') || 'N/A',
        "R#{invoice.total_amount.to_i}",
        invoice.paid? ? 'Paid' : 'Unpaid'
      ]
    end

    pdf.font 'Helvetica', size: 8
    pdf.table(table_data,
              header: true,
              column_widths: [40, 120, 55, 35, 55, 55, 50, 45],
              cell_style: {
                padding: [5, 3],
                borders: [:bottom],
                border_color: 'DDDDDD'
              }) do |table|
      # Header row styling
      table.row(0).font_style = :bold
      table.row(0).background_color = 'F5F5F5'
      table.row(0).borders = [:top, :bottom]
      table.row(0).border_width = 1.5
      table.row(0).size = 9

      # Right align amount column
      table.column(6).align = :right
    end

    pdf.move_down 20

    # Check if we need a new page for payment details
    pdf.start_new_page if pdf.cursor < 200
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
      ['Reference:', "Customer ID: #{@user.id}"]
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
    pdf.text 'Please use your Customer ID as the payment reference.'
    pdf.move_down 5
    pdf.text "You can also pay via SnapScan at: https://pos.snapscan.io/qr/8jQ1QVVb?id=#{@user.customer_id}&amount=#{@invoice.total_amount.to_i}00&invoice_id=#{@invoice.id}"
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
