
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

      # Handle statement payments without invoice_id - find oldest unpaid invoice
      @invoice = if @extra["invoice_id"].present?
        Invoice.find_by(id: @extra["invoice_id"].to_i)
      else
        # Statement payment - find oldest unpaid invoice for this user
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
      # Idempotency check - prevent duplicate webhook processing
      existing_payment = Payment.find_by(snapscan_id: @payload["id"])
      if existing_payment
        Rails.logger.info "Payment already processed for snapscan_id #{@payload['id']}"
        return :duplicate
      end

      payment_amount = @payload["totalAmount"].to_f / 100.0 # SnapScan sends in cents
      invoice_total = @invoice.total_amount.to_f
      pending_subscriptions = @user.subscriptions.where(status: :pending).order(created_at: :asc)

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

        # Cascade payment through subscriptions in order
        remaining_payment = payment_amount
        activated_subscriptions = []
        unactivated_subscriptions = []
        paid_invoices = []

        pending_subscriptions.each do |subscription|
          subscription_cost = calculate_subscription_cost(subscription)

          if remaining_payment >= subscription_cost
            # Fully covers this subscription - activate it
            subscription.activate_subscription
            first_collection = CreateFirstCollectionJob.perform_now(subscription)
            add_order_items_to_collection(first_collection)

            remaining_payment -= subscription_cost
            activated_subscriptions << subscription

            # Find and mark this subscription's invoice as paid
            subscription_invoice = subscription.invoices.where(paid: false).order(issued_date: :asc).first
            if subscription_invoice && subscription_invoice.total_amount <= subscription_cost
              subscription_invoice.update!(paid: true)
              paid_invoices << subscription_invoice
              Rails.logger.info "Marked invoice #{subscription_invoice.id} as paid for subscription #{subscription.id}"
            end

            Rails.logger.info "Activated subscription #{subscription.id} (cost: R#{subscription_cost}). Remaining: R#{remaining_payment}"
          else
            # Not enough to cover this subscription
            unactivated_subscriptions << subscription
            Rails.logger.info "Insufficient funds for subscription #{subscription.id} (needs: R#{subscription_cost}, have: R#{remaining_payment})"
          end
        end

        # Send appropriate notification
        if activated_subscriptions.any?
          if unactivated_subscriptions.empty?
            # All subscriptions activated
            Rails.logger.info "✅ Full payment received. Activated #{activated_subscriptions.count} subscription(s). Marked #{paid_invoices.count} invoice(s) as paid."
          else
            # Partial payment that activated some subscriptions
            total_owed = pending_subscriptions.sum { |s| calculate_subscription_cost(s) }
            shortfall = total_owed - payment_amount

            PaymentMailer.partial_payment_alert(
              payment: payment,
              invoice: @invoice,
              user: @user,
              activated_subscriptions: activated_subscriptions,
              shortfall: shortfall,
              pending_subscriptions: unactivated_subscriptions
            ).deliver_now

            Rails.logger.warn "⚠️ Partial payment. Activated #{activated_subscriptions.count} subscription(s). Marked #{paid_invoices.count} invoice(s) as paid. Shortfall: R#{shortfall.round(2)}"
          end
        else
          # Payment doesn't cover even first subscription
          first_sub_cost = calculate_subscription_cost(pending_subscriptions.first) if pending_subscriptions.first
          total_owed = pending_subscriptions.sum { |s| calculate_subscription_cost(s) }
          shortfall = total_owed - payment_amount

          PaymentMailer.insufficient_payment_alert(
            payment: payment,
            invoice: @invoice,
            user: @user,
            required_amount: first_sub_cost,
            shortfall: shortfall
          ).deliver_now

          Rails.logger.error "❌ Insufficient payment. No subscriptions activated. Shortfall: R#{shortfall.round(2)}"
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
