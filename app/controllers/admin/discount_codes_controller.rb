class Admin::DiscountCodesController < Admin::BaseController
  before_action :set_discount_code, only: [:show, :edit, :update, :destroy]

  def index
    @discount_codes = DiscountCode.order(created_at: :desc)
  end

  def new
    @discount_code = DiscountCode.new
  end

  def create
    @discount_code = DiscountCode.new(discount_code_params)
    @discount_code.used_count = 0

    if @discount_code.save
      redirect_to admin_discount_code_path(@discount_code), notice: "Code created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @discount_code.update(discount_code_params)
      redirect_to admin_discount_code_path(@discount_code), notice: "Code updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discount_code.destroy
    redirect_to admin_discount_codes_path, notice: "Code deleted."
  end

  private

  def set_discount_code
    @discount_code = DiscountCode.find(params[:id])
  end

  def discount_code_params
    params.require(:discount_code).permit(:code, :discount_cents, :discount_percent, :expires_at, :usage_limit)
  end
end
