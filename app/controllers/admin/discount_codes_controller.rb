class Admin::DiscountCodesController < Admin::BaseController

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
      render :new
    end
  end

  def show
    @discount_code = DiscountCode.find(params[:id])
    # We'll show the QR code here later
  end

  private

  def discount_code_params
    params.require(:discount_code).permit(:code, :discount_cents, :discount_percent, :expires_at, :usage_limit)
  end
end
