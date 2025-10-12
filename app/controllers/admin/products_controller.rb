class Admin::ProductsController < ApplicationController
  before_action :set_product, only: [:edit, :update]

  def index
    @products = Product.all.order(:title)
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to admin_products_path, notice: "Product created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Filter out empty image strings
    if params[:product][:images].present?
      params[:product][:images].reject!(&:blank?)
    end
    stock = params[:product][:stock]

    if @product.update(product_params)
      @product.update(stock: stock)

      redirect_to admin_products_path, notice: "Product updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:title, :description, :price, :is_active, :stock, images: [])
  end
end
