# app/services/quotation_pdf_generator.rb
require 'prawn'
require 'prawn/table'

class QuotationPdfGenerator
  def initialize(quotation)
    @quotation = quotation
    @user = quotation.user
  end

  def generate
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with branding
      add_header(pdf)

      # Quotation info and customer details
      add_quotation_details(pdf)

      # Quotation items table
      add_items_table(pdf)

      # Contact details
      add_contact_details(pdf)

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

  def add_quotation_details(pdf)
    # Quotation title and number
    pdf.font 'Helvetica', size: 20, style: :bold
    pdf.text "Quotation ##{@quotation.number || @quotation.id}"
    pdf.move_down 20

    # Two column layout for quotation details
    details_data = [
      ['For:', @quotation.customer_name],
      ['Email:', @quotation.customer_email || 'N/A']
    ]

    # Add phone for customers or prospects
    if @user.present?
      details_data << ['Phone:', @user.phone_number] if @user.phone_number.present?
      if @user.subscriptions.any?
        details_data << ['Customer ID:', @user.subscriptions.last.customer_id]
      end
    else
      details_data << ['Phone:', @quotation.prospect_phone] if @quotation.prospect_phone.present?
      details_data << ['Company:', @quotation.prospect_company] if @quotation.prospect_company.present?
    end

    details_data << ['Quote Date:', @quotation.created_date.strftime('%e %b %Y')]
    details_data << ['Valid Until:', @quotation.expires_at.strftime('%e %b %Y')]

    pdf.font 'Helvetica', size: 10
    pdf.table(details_data,
              column_widths: [100, 400],
              cell_style: {
                borders: [],
                padding: [3, 5]
              }) do |table|
      table.column(0).font_style = :bold
    end

    # Add notes if present
    if @quotation.notes.present?
      pdf.move_down 15
      pdf.font 'Helvetica', size: 10, style: :bold
      pdf.text 'Notes:'
      pdf.font 'Helvetica', size: 10
      pdf.move_down 5
      pdf.text @quotation.notes
    end

    pdf.move_down 25
  end

  def add_items_table(pdf)
    pdf.font 'Helvetica', size: 12, style: :bold
    pdf.text 'Items'
    pdf.move_down 10

    # Prepare table data
    table_data = [['Qty', 'Item', 'Unit Price', 'Amount']]

    @quotation.quotation_items.each do |item|
      description = item.product.title
      unit_price = "R#{item.amount.to_i}"
      amount = "R#{(item.amount * item.quantity).to_i}"
      table_data << [item.quantity.to_i.to_s, description, unit_price, amount]
    end

    # Create table
    pdf.font 'Helvetica', size: 10
    pdf.table(table_data,
              header: true,
              column_widths: [50, 300, 80, 85],
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

      # Right align price columns
      table.column(2).align = :right
      table.column(3).align = :right

      # Center align quantity column
      table.column(0).align = :center
    end

    pdf.move_down 15

    # Total
    pdf.font 'Helvetica', size: 14, style: :bold
    pdf.text "Total: R#{@quotation.total_amount.to_i}", align: :right
    pdf.move_down 30
  end

  def add_contact_details(pdf)
    pdf.font 'Helvetica', size: 12, style: :bold
    pdf.text 'Questions?'
    pdf.move_down 10

    pdf.font 'Helvetica', size: 10
    pdf.text 'If you have any questions about this quotation or would like to proceed, please contact us:'
    pdf.move_down 10

    contact_data = [
      ['Email:', 'howzit@gooi.me'],
      ['Phone:', '+27 78 532 5513'],
      ['Website:', 'www.gooi.me']
    ]

    pdf.table(contact_data,
              column_widths: [80, 420],
              cell_style: {
                borders: [],
                padding: [3, 5]
              }) do |table|
      table.column(0).font_style = :bold
    end

    unless @quotation.expired?
      pdf.move_down 15
      pdf.font 'Helvetica', size: 9, style: :italic
      pdf.text "This quotation is valid until #{@quotation.expires_at.strftime('%B %d, %Y')}."
      pdf.text 'We look forward to working with you!'
    end
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
