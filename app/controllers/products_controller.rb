class ProductsController < ApplicationController

  def index
    @products = Product.all
  end
  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    @product.is_active = true
    if @product.save
      redirect_to invoices_path
    else
      render :new, status: :unprocessable_entity
    end

  end

  private
  def product_params
    params.require(:product).permit(:title, :description, :price)
  end
end
