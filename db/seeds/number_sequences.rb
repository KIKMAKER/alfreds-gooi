# Invoice#set_number and Quotation#set_number call nextval() on these Postgres
# sequences. They were created with raw SQL in 20260614123509, which schema.rb
# can't represent, so `db:reset` / `db:schema:load` leaves them missing.
# IF NOT EXISTS makes this a no-op on a DB (or prod) that already has them.
conn = ActiveRecord::Base.connection

{ "invoice_number_seq" => Invoice, "quotation_number_seq" => Quotation }.each do |seq, model|
  conn.execute "CREATE SEQUENCE IF NOT EXISTS #{seq} START WITH #{model.maximum(:number).to_i + 1}"
end
