class OrdersController < ApplicationController
  before_action :set_order, only: [:checkout, :attach_to_collection, :mark_delivered]

  def add_item
    product = Product.find(params[:product_id])
    quantity = params[:quantity].to_i

    # Find or create pending order
    @order = current_user.orders.pending.last || current_user.orders.create!(status: :pending)

    # Find or create order item
    order_item = @order.order_items.find_or_initialize_by(product: product)
    order_item.quantity = (order_item.quantity || 0) + quantity
    order_item.save!

    @order.save! # Triggers calculate_total callback

    redirect_to shop_index_path, notice: "#{product.title} added to your order!"
  end

  def remove_item
    order_item = OrderItem.find(params[:id])
    order_item.destroy
    redirect_to shop_index_path, notice: "Item removed from your order."
  end

  def checkout
    @next_collection = current_user.collections.where('date >= ?', Date.today).order(:date).first
  end

  def attach_to_collection
    collection = Collection.find(params[:collection_id])

    if @order.update(collection: collection, status: :paid)
      # Create invoice for the order
      invoice = Invoice.create!(
        subscription: collection.subscription,
        issued_date: Time.current,
        due_date: Time.current + 1.week,
        total_amount: @order.total_amount
      )

      # Add order items to invoice
      @order.order_items.each do |item|
        InvoiceItem.create!(
          invoice: invoice,
          product: item.product,
          quantity: item.quantity,
          amount: item.price
        )
      end

      redirect_to invoice_path(invoice), notice: "Order confirmed! Your items will be delivered on #{collection.date.strftime('%A, %B %e')}."
    else
      redirect_to checkout_order_path(@order), alert: "Could not complete order."
    end
  end

  def mark_delivered
    if @order.mark_delivered!
      redirect_to edit_collection_path(@order.collection), notice: "Order ##{@order.id} marked as delivered! Stock updated."
    else
      redirect_to edit_collection_path(@order.collection), alert: "Could not mark order as delivered."
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end
