class CreateInvoiceAndQuotationNumberSequences < ActiveRecord::Migration[7.2]
  def up
    invoice_start = Invoice.maximum(:number).to_i + 1
    execute "CREATE SEQUENCE invoice_number_seq START WITH #{invoice_start}"
    execute "ALTER SEQUENCE invoice_number_seq OWNED BY invoices.number"

    quotation_start = Quotation.maximum(:number).to_i + 1
    execute "CREATE SEQUENCE quotation_number_seq START WITH #{quotation_start}"
    execute "ALTER SEQUENCE quotation_number_seq OWNED BY quotations.number"
  end

  def down
    execute "DROP SEQUENCE IF EXISTS invoice_number_seq"
    execute "DROP SEQUENCE IF EXISTS quotation_number_seq"
  end
end
