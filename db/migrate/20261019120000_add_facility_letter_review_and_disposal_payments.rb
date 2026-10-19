class AddFacilityLetterReviewAndDisposalPayments < ActiveRecord::Migration[7.1]
  def change
    # Review state of the signed facility confirmation letter:
    # 0 not_submitted, 1 submitted (awaiting Gooi review), 2 approved, 3 rejected.
    add_column :drop_off_sites, :facility_letter_status, :integer, default: 0, null: false
    add_column :drop_off_sites, :facility_letter_submitted_at, :datetime
    add_column :drop_off_sites, :facility_approved_at, :datetime
    add_column :drop_off_sites, :facility_rejection_reason, :text

    # What Gooi owes a charging site for one calendar month. Not an invoice (we are
    # the payer): a snapshot of kg x rate taken when the payment request is sent.
    create_table :disposal_payments do |t|
      t.references :drop_off_site, null: false, foreign_key: true
      t.date    :period, null: false # first day of the month
      t.decimal :kg,         precision: 10, scale: 2, null: false
      t.decimal :fee_per_kg, precision: 8,  scale: 2, null: false
      t.decimal :amount,     precision: 10, scale: 2, null: false
      t.integer :status, default: 0, null: false # 0 requested, 1 paid
      t.datetime :requested_at
      t.datetime :paid_at
      t.timestamps
    end
    add_index :disposal_payments, [:drop_off_site_id, :period], unique: true
  end
end
