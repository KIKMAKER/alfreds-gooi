# app/services/snapscan/sync_service.rb
module Snapscan
  class SyncService
    def initialize(api_key)
      @api_key = api_key
      @service = Snapscan::ApiClient.new(api_key)
    end

    def sync!
      payments = @service.fetch_payments || []
      payments.each do |snapscan_data|
        next if Payment.exists?(snapscan_id: snapscan_data["id"])

        user = User.find_by(customer_id: snapscan_data["merchantReference"])
        next unless user

        invoice_id = snapscan_data.dig("extra", "invoiceId") || snapscan_data.dig("extra", "invoice_id")
        invoice = Invoice.find_by(id: invoice_id.to_i) if invoice_id

        Payment.create!(
          snapscan_id: snapscan_data["id"],
          status: snapscan_data["status"],
          total_amount: snapscan_data["totalAmount"],
          tip_amount: snapscan_data["tipAmount"],
          fee_amount: snapscan_data["feeAmount"],
          settle_amount: snapscan_data["settleAmount"],
          date: snapscan_data["date"],
          user_reference: snapscan_data["userReference"],
          merchant_reference: snapscan_data["merchantReference"],
          user_id: user.id,
          invoice_id: invoice&.id
        ).tap do |payment|
          if payment.status == "completed" && invoice
            invoice.update!(paid: true)
            subscription = invoice.subscription
            subscription&.update!(status: "active", start_date: subscription.suggested_start_date)
            CreateFirstCollectionJob.perform_later(subscription)
          end
        end
      end
    end
  end
end
