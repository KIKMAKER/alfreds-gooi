cost_model = CostModel.first || CostModel.new

cost_model.update!(
  founder_salary: 20_000, driver_salary: 13_200,
  depreciation: 3235, maintenance: 667, hosting: 587,
  data_comms: 439, bank_fees: 278, licence: 200,
  fuel_per_route_day: 136, route_days_per_month: 22,
  marketing: 1500, supplies: 500, other: 300,
  num_bakkies: 1,
  target_monthly_litres: cost_model.target_monthly_litres.to_f.zero? ? 12_000 : cost_model.target_monthly_litres,
  minimum_margin_pct: cost_model.minimum_margin_pct.to_f.zero? ? 0.25 : cost_model.minimum_margin_pct
)

puts "  ✓ Cost model: monthly_total = R#{cost_model.monthly_total}"
