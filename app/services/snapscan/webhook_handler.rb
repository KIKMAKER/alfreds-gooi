# app/services/snapscan/webhook_handler.rb
module Snapscan
  class WebhookHandler
    def initialize(payload)
      @payload = payload
      @extra = (@payload["extra"] || {}).transform_keys(&:underscore)
    end

    def process!
      @user = User.find_by(customer_id: @payload["merchantReference"])
      raise "User not found for merchantReference #{@payload['merchantReference']}" unless @user

      @invoice = if @extra["invoice_id"].present?
        Invoice.find_by(id: @extra["invoice_id"].to_i)
      else
        @user.invoices.where(paid: false).order(issued_date: :asc).first
      end

      raise "Invoice not found for user #{@user.customer_id}" unless @invoice

      case @payload["status"]
      when "completed"
        create_payment_and_process_subscription
      when "error"
        Rails.logger.error "❌ Payment failed: #{@payload}"
        :failed
      else
        Rails.logger.warn "⚠️ Unhandled payment status: #{@payload["status"]}"
        :ignored
      end
    end

    private

    def create_payment_and_process_subscription
      existing_payment = Payment.find_by(snapscan_id: @payload["id"])
      if existing_payment
        Rails.logger.info "Payment already processed for snapscan_id #{@payload['id']}"
        return :duplicate
      end

      payment_amount = @payload["totalAmount"].to_f / 100.0
      invoice_total  = @invoice.total_amount.to_f

      ActiveRecord::Base.transaction do
        payment = Payment.create!(
          snapscan_id:        @payload["id"],
          status:             @payload["status"],
          total_amount:       @payload["totalAmount"],
          tip_amount:         @payload["tipAmount"],
          fee_amount:         @payload["feeAmount"],
          settle_amount:      @payload["settleAmount"],
          date:               @payload["date"],
          user_reference:     @payload["userReference"],
          merchant_reference: @payload["merchantReference"],
          user:               @user,
          invoice:            @invoice,
          payment_type:       :snapscan
        )

        # Mark invoice paid and activate all pending subscriptions unconditionally
        @invoice.update!(paid: true)

        @user.subscriptions.where(status: :pending).order(created_at: :asc).each do |subscription|
          subscription.activate_subscription
          first_collection = CreateFirstCollectionJob.perform_now(subscription)
          add_order_items_to_collection(first_collection)
        end

        # Alert if payment is short — you handle it manually with the customer
        if payment_amount < invoice_total
          shortfall = invoice_total - payment_amount
          PaymentMailer.short_payment_alert(
            payment: payment,
            invoice: @invoice,
            user:    @user,
            shortfall: shortfall
          ).deliver_now
          Rails.logger.warn "⚠️ Short payment for #{@user.email}. Paid R#{payment_amount}, invoice R#{invoice_total}, shortfall R#{shortfall.round(2)}. Invoice marked paid, alert sent."
        else
          Rails.logger.info "✅ Full payment received for #{@user.email}. Invoice #{@invoice.id} marked paid."
        end
      end

      :success
    rescue StandardError => e
      Rails.logger.error "Error processing payment: #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end

    def add_order_items_to_collection(collection)
      return unless collection
      compost = Product.find_by(title: "Compost bin bags")
      soil    = Product.find_by(title: "Soil for Life Compost")

      if compost
        quantity = @invoice.invoice_items.find_by(product_id: compost.id)&.quantity
        collection.update!(needs_bags: quantity) if quantity
      end

      if soil
        quantity = @invoice.invoice_items.find_by(product_id: soil.id)&.quantity
        collection.update!(soil_bag: quantity) if quantity
      end
    end
  end
end
