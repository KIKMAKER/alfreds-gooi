class Admin::CostModelsController < Admin::BaseController
  def edit
    @cost_model = CostModel.current
  end

  def update
    @cost_model = CostModel.current
    if @cost_model.update(cost_model_attributes)
      redirect_to admin_financials_path, notice: "Cost model updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # The form collects margin as a whole-number percent (e.g. 25) since that's
  # how the business thinks about it; minimum_margin_pct is stored as a
  # fraction (0.25) to match how CostModel#price_guidance uses it.
  def cost_model_attributes
    attrs = cost_model_params.to_h
    attrs["minimum_margin_pct"] = attrs.delete("minimum_margin_percent").to_f / 100.0
    attrs
  end

  def cost_model_params
    params.require(:cost_model).permit(
      :founder_salary, :driver_salary,
      :depreciation, :maintenance, :hosting, :data_comms, :bank_fees, :licence,
      :fuel_per_route_day, :route_days_per_month, :marketing, :supplies, :other,
      :num_bakkies, :target_monthly_litres, :minimum_margin_percent
    )
  end
end
