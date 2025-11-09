
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
      # Idempotency check - prevent duplicate webhook processing
      existing_payment = Payment.find_by(snapscan_id: @payload["id"])
      if existing_payment
        Rails.logger.info "Payment already processed for snapscan_id #{@payload['id']}"
        return :duplicate
      end

      payment_amount = @payload["totalAmount"].to_f / 100.0 # SnapScan sends in cents
      invoice_total = @invoice.total_amount.to_f
      pending_subscriptions = @user.subscriptions.where(status: :pending, is_paused: true).order(created_at: :asc)

      ActiveRecord::Base.transaction do
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

        # Check if payment covers full invoice amount
        if payment_amount >= invoice_total
          # Full payment - activate all pending subscriptions
          pending_subscriptions.each do |subscription|
            subscription.activate_subscription
            first_collection = CreateFirstCollectionJob.perform_now(subscription)
            add_order_items_to_collection(first_collection)
          end
          Rails.logger.info "Full payment received. Activated #{pending_subscriptions.count} subscriptions."
        else
          # Partial payment - check if it covers first subscription
          first_sub = pending_subscriptions.first
          if first_sub
            first_sub_cost = calculate_subscription_cost(first_sub)

            if payment_amount >= first_sub_cost
              # Activate first subscription
              first_sub.activate_subscription
              first_collection = CreateFirstCollectionJob.perform_now(first_sub)
              add_order_items_to_collection(first_collection)
              shortfall = invoice_total - payment_amount

              # Send alert email
              PaymentMailer.partial_payment_alert(
                payment: payment,
                invoice: @invoice,
                user: @user,
                activated_subscription: first_sub,
                shortfall: shortfall,
                pending_subscriptions: pending_subscriptions - [first_sub]
              ).deliver_now

              Rails.logger.info "Partial payment received. Activated 1 subscription. Shortfall: R#{shortfall}"
            else
              # Payment doesn't even cover first subscription
              PaymentMailer.insufficient_payment_alert(
                payment: payment,
                invoice: @invoice,
                user: @user,
                required_amount: first_sub_cost,
                shortfall: invoice_total - payment_amount
              ).deliver_now

              Rails.logger.error "Insufficient payment. Does not cover first subscription."
            end
          end
        end
      end

      :success
    rescue StandardError => e
      Rails.logger.error "Error processing payment: #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end

    def calculate_subscription_cost(subscription)
      # Calculate the cost for this subscription from invoice items
      # This is a simplified version - you may need to adjust based on your invoice structure
      plan_name = subscription.plan == "XL" ? "XL" : subscription.plan.downcase
      product_title = "#{plan_name} #{subscription.duration} month"

      invoice_item = @invoice.invoice_items.joins(:product).find_by(products: { title: product_title })
      return 0.0 unless invoice_item

      invoice_item.quantity * invoice_item.amount
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
