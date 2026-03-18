class AddEventFieldsToQuotations < ActiveRecord::Migration[7.2]
  def change
    add_column :quotations, :quote_type, :string, default: "subscription", null: false
    add_column :quotations, :event_date, :date
    add_column :quotations, :event_name, :string
    add_column :quotations, :event_venue, :string
  end
end
