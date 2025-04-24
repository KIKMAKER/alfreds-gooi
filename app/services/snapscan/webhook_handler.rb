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

      @invoice = Invoice.find_by(id: @extra["invoice_id"].to_i)
      raise "Invoice not found with id #{@extra['invoice_id']}" unless @invoice

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
      payment = Payment.create!(
        snapscan_id: @payload["id"],
        status: @payload["status"],
        total_amount: @payload["totalAmount"],
        tip_amount: @payload["tipAmount"],
        fee_amount: @payload["feeAmount"],
        settle_amount: @payload["settleAmount"],
        date: @payload["date"],
        user_reference: @payload["userReference"],
        merchant_reference: @payload["merchantReference"],
        user: @user,
        invoice: @invoice
      )

      @invoice.update!(paid: true)
      subscription = @invoice.subscription
      return unless subscription

      subscription.update!(
        status: 'active',
        start_date: subscription.suggested_start_date,
        is_paused: false
      )

      referral = Referral.find_by(referee_id: subscription.user_id, referrer_id: User.find_by(referral_code: subscription.referral_code)&.id)
      referral&.completed!

      first_collection = CreateFirstCollectionJob.perform_now(subscription)
      add_order_items_to_collection(first_collection)

      :success
    end

    def add_order_items_to_collection(collection)
      compost = Product.find_by(title: "Compost bin bags")
      soil = Product.find_by(title: "Soil for Life Compost")
      invoice_items = @invoice.invoice_items

      if compost
        quantity = invoice_items.find_by(product_id: compost.id)&.quantity
        collection.update!(needs_bags: quantity) if quantity
      end

      if soil
        quantity = invoice_items.find_by(product_id: soil.id)&.quantity
        collection.update!(soil_bag: quantity) if quantity
      end
    end
  end
end
