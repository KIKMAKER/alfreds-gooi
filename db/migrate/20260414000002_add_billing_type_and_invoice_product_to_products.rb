class AddBillingTypeAndInvoiceProductToProducts < ActiveRecord::Migration[7.1]
  INVOICE_ONLY_TITLES = [
    "Commercial collection fee (6-month)",
    "Commercial collection fee (12-month)",
    "Commercial collection fee (3-month)",
    "Commercial volume per 25L bucket",
    "Commercial volume per 45L bucket",
    "Commercial volume per 50L bucket",
    "Standard 1 month subscription",
    "Standard 3 month subscription",
    "Standard 6 month subscription",
    "Standard 12 month subscription",
    "Standard 6 month OG subscription",
    "Standard 1 month OG ad hoc subscription",
    "XL 1 month subscription",
    "XL 3 month subscription",
    "XL 6 month subscription",
    "XL 12 month subscription",
    "Once-off Collection",
    "Referral discount standard 1 month",
    "Referral discount standard 3 month",
    "Referral discount standard 6 month",
    "Referral discount XL 1 month",
    "Referral discount XL 3 month",
    "Referral discount XL 6 month",
    "Referred a friend discount (R50)"
  ].freeze

  def change
    add_column :products, :billing_type, :string, default: "standard", null: false
    add_column :products, :invoice_product_id, :bigint, null: true
    add_index  :products, :invoice_product_id

    reversible do |dir|
      dir.up do
        # Existing quote_only: true products → quote_only
        execute "UPDATE products SET billing_type = 'quote_only' WHERE quote_only = TRUE"

        # Known invoice-only products → invoice_only
        titles = INVOICE_ONLY_TITLES.map { |t| "'#{t.gsub("'", "''")}'" }.join(", ")
        execute "UPDATE products SET billing_type = 'invoice_only' WHERE title IN (#{titles}) AND quote_only = FALSE"

        # Everything else keeps the 'standard' default
      end
    end
  end
end
