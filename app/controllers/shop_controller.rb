class ShopController < ApplicationController
  def index
    @products = Product.shop_items.order(:title)
    @current_order = current_user.orders.pending.last || current_user.orders.build
  end
end
