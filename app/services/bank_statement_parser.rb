require 'csv'

class BankStatementParser
  CATEGORIZATION_RULES = {
    # Bank fees - check first as most specific
    /account fee|service fee|monthly fee|acc fee|monthlyaccountfee|#service fees|#monthly account fee/i => :bank_fees,

    # Salaries & Wages - ATM withdrawals often used for wages
    /atm cash/i => :salaries_wages,

    # Fuel
    /shell|engen|petrol|bp|total|caltex|garage|fuel|ae claremont fc/i => :fuel,

    # Bags & Packaging
    /bonnie bio bags|bag/i => :bags,

    # Marketing materials
    /flyer|sticker|card|twh flyers/i => :marketing,

    # Software subscriptions
    /twilio|heroku/i => :software_subscriptions,

    # Airtime & Data
    /airtime|data|smart-ap prepaid/i => :airtime_data,

    # Staff food & refreshments
    /coffee|tea|refreshment|snack|food.*staff|staff.*food/i => :staff_food,

    # Buckets & starter kits
    /bucket stickers/i => :buckets,

    # Starter kits & packaging materials
    /welcome cards/i => :starter_kits,

    # Operational costs - food, supplies
    /cab foods/i => :other,

    # Rent
    /rent|lease|landlord/i => :rent,

    # General categorization (lower priority)
    /vehicle|repair|service|maintenance|mechanic|auto/i => :vehicle_maintenance,
    /insurance/i => :insurance_general,
    /toll/i => :tolls_parking,
    /electric|water|municipal|rates|utilities/i => :utilities,
    /office|stationery|supplies/i => :office_supplies,
    /accountant|lawyer|legal|professional/i => :professional_fees
  }.freeze

  def initialize(file)
    @file = file
    @errors = []
  end

  def parse
    begin
      content = @file.read.force_encoding('UTF-8')

      # Try to detect separator (comma or tab)
      separator = content.include?("\t") ? "\t" : ","

      # Parse once to check if first row looks like headers
      first_parse = CSV.parse(content, col_sep: separator, skip_blanks: true)
      first_row = first_parse.first

      # Check if first row looks like headers (contains text like "Date", "Description", etc.)
      has_headers = first_row.any? { |cell| cell&.match?(/date|description|amount|balance|transaction/i) }

      if has_headers
        rows = CSV.parse(content,
                        headers: true,
                        col_sep: separator,
                        skip_blanks: true,
                        header_converters: ->(h) { h.strip },
                        converters: ->(f) { f&.strip })
        detect_bank_format(rows)
        parse_rows(rows)
      else
        # No headers - assume tab-separated FNB format: Date, Amount, Balance, Description
        parse_fnb_no_headers(first_parse)
      end
    rescue CSV::MalformedCSVError => e
      @errors << "Invalid CSV format: #{e.message}"
      []
    rescue => e
      @errors << "Error parsing file: #{e.message}"
      []
    end
  end

  def errors
    @errors
  end

  private

  def detect_bank_format(rows)
    headers = rows.headers.map(&:downcase)

    # Normalise Amount_ZAR → treat as standard Amount column
    @amount_zar_format = headers.include?('amount_zar')
    # Detect if dates are in "DD Mon" format (no year) — infer year at parse time
    @yearless_dates = headers.include?('date') && rows.first&.[]('Date')&.match?(/^\d{1,2} [A-Za-z]{3}$/)

    @bank_format = if headers.include?('date') && headers.include?('description') &&
                      (headers.include?('amount') || @amount_zar_format)
                     :standard
                   elsif headers.include?('transaction date') && headers.include?('beneficiary')
                     :capitec
                   else
                     :standard
                   end
  end

  def parse_rows(rows)
    expenses = []

    rows.each_with_index do |row, index|
      begin
        expense_hash = parse_row(row)
        next unless expense_hash  # Skip if not an expense (e.g., income)

        expenses << expense_hash
      rescue => e
        @errors << "Row #{index + 2}: #{e.message}"
      end
    end

    expenses
  end

  def parse_row(row)
    case @bank_format
    when :capitec
      parse_capitec_row(row)
    else
      parse_standard_row(row)
    end
  end

  def parse_standard_row(row)
    date_str = row['Date'] || row['date']
    transaction_date = @yearless_dates ? parse_yearless_date(date_str) : parse_date(date_str)
    description = row['Description'] || row['description'] || ''
    # Support Amount_ZAR column name (used in manually-exported Gooi CSVs)
    amount_str = row['Amount'] || row['amount'] || row['Amount_ZAR'] || row['amount_zar'] || '0'

    # Parse amount
    amount = parse_amount(amount_str)

    # Skip if it's income (positive amount)
    return nil if amount > 0

    # Make amount positive for expense tracking
    amount = amount.abs

    # Extract vendor from description
    vendor = extract_vendor(description)

    {
      transaction_date: transaction_date,
      amount: amount,
      description: description,
      vendor: vendor,
      suggested_category: auto_categorize(description),
      reference_number: row['Reference'] || row['reference']
    }
  end

  def parse_capitec_row(row)
    transaction_date = parse_date(row['Transaction Date'] || row['transaction date'])
    beneficiary = row['Beneficiary'] || row['beneficiary'] || ''
    debit_str = row['Debit'] || row['debit'] || '0'
    credit_str = row['Credit'] || row['credit'] || '0'

    debit = parse_amount(debit_str)
    credit = parse_amount(credit_str)

    # Skip if it's income (credit > 0, debit = 0)
    return nil if credit > 0 && debit.zero?

    # Use debit amount
    amount = debit

    {
      transaction_date: transaction_date,
      amount: amount,
      description: beneficiary,
      vendor: beneficiary,
      suggested_category: auto_categorize(beneficiary),
      reference_number: nil
    }
  end

  def parse_date(date_str)
    return Date.current unless date_str

    # Try multiple date formats
    formats = ['%Y-%m-%d', '%d/%m/%Y', '%m/%d/%Y', '%Y/%m/%d', '%d-%m-%Y', '%d %b %Y', '%d %B %Y']

    formats.each do |format|
      begin
        return Date.strptime(date_str, format)
      rescue ArgumentError
        next
      end
    end

    # If all formats fail, try Date.parse
    Date.parse(date_str)
  rescue ArgumentError
    Date.current
  end

  # Handle "25 Mar" style dates with no year. Assumes current year; steps back
  # one year if that would place the date in the future (e.g. a March statement
  # uploaded in January).
  def parse_yearless_date(date_str)
    return Date.current unless date_str

    begin
      candidate = Date.strptime("#{date_str} #{Date.current.year}", '%d %b %Y')
      candidate > Date.current ? candidate.prev_year : candidate
    rescue ArgumentError
      Date.current
    end
  end

  def parse_amount(amount_str)
    return 0.0 unless amount_str

    # Remove currency symbols, commas, and spaces
    cleaned = amount_str.to_s.gsub(/[R\s,]/, '')

    # Handle parentheses as negative (some banks use this)
    if cleaned.match?(/\(.*\)/)
      cleaned = cleaned.gsub(/[()]/, '')
      return -cleaned.to_f
    end

    cleaned.to_f
  end

  def extract_vendor(description)
    # Simple vendor extraction - take first few words
    description.split.first(3).join(' ')
  end

  def auto_categorize(description)
    CATEGORIZATION_RULES.each do |pattern, category|
      return category if description.match?(pattern)
    end

    :other  # Default category
  end

  def parse_fnb_no_headers(rows)
    expenses = []

    rows.each_with_index do |row, index|
      begin
        # Skip if row doesn't have enough columns
        next unless row.length >= 4

        date_str = row[0]
        amount_str = row[1]
        description = row[3] || ''

        # Parse date (format: YYYY/MM/DD)
        transaction_date = parse_date(date_str)

        # Parse amount
        amount = parse_amount(amount_str)

        # Skip if it's income (positive amount)
        next if amount > 0

        # Make amount positive for expense tracking
        amount = amount.abs

        # Skip zero amounts
        next if amount.zero?

        # Extract vendor from description
        vendor = extract_vendor(description)

        expenses << {
          transaction_date: transaction_date,
          amount: amount,
          description: description,
          vendor: vendor,
          suggested_category: auto_categorize(description),
          reference_number: nil
        }
      rescue => e
        @errors << "Row #{index + 1}: #{e.message}"
      end
    end

    expenses
  end
end
