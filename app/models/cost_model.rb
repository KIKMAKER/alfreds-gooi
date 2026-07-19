# Single source of truth for the business's real cost structure. Admin-editable,
# but intended to hold exactly one row (see .current) — every pricing floor and
# guidance figure in the app derives from this record plus a volume assumption.
class CostModel < ApplicationRecord
  validates :founder_salary, :driver_salary,
            :depreciation, :maintenance, :hosting, :data_comms, :bank_fees, :licence,
            :fuel_per_route_day, :route_days_per_month,
            :marketing, :supplies, :other,
            :num_bakkies, :target_monthly_litres, :minimum_margin_pct,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  # The one row this app runs on. Views/services should always read cost
  # figures through here rather than querying CostModel directly, so there's
  # a single place to change if we ever need per-period cost models.
  def self.current
    first_or_create!(
      founder_salary: 20_000, driver_salary: 13_200,
      depreciation: 3235, maintenance: 667, hosting: 587,
      data_comms: 439, bank_fees: 278, licence: 200,
      fuel_per_route_day: 136, route_days_per_month: 22,
      marketing: 1500, supplies: 500, other: 300,
      num_bakkies: 1, target_monthly_litres: 12_000, minimum_margin_pct: 0.25
    )
  end

  def people_total
    founder_salary + driver_salary
  end

  def fixed_per_bakkie_total
    depreciation + maintenance + hosting + data_comms + bank_fees + licence
  end

  def variable_total
    (fuel_per_route_day * route_days_per_month) + marketing + supplies + other
  end

  def monthly_total
    people_total + (fixed_per_bakkie_total * num_bakkies) + variable_total
  end

  # Real trailing-3-month average monthly litres, computed live from actual
  # collection data (not persisted — it's a fact about the business, not a
  # setting). Distinct from target_monthly_litres, which is the admin's
  # capacity assumption used for forward-looking pricing.
  def trailing_3mo_avg_litres
    total = Collection.total_litres_between(3.months.ago.to_date, Date.current)
    (total / 3.0).round(1)
  end

  # R/L floor implied by what the business is actually collecting right now.
  def floor_current
    litres = trailing_3mo_avg_litres
    return nil if litres.zero?
    (monthly_total / litres).round(2)
  end

  # R/L floor implied by the admin's target capacity — the forward-looking
  # number pricing should be built on.
  def floor_target
    return nil if target_monthly_litres.to_f.zero?
    (monthly_total / target_monthly_litres).round(2)
  end

  # The R/L quotes should actually be priced at: floor_target plus margin.
  def price_guidance
    floor = floor_target
    return nil unless floor
    (floor * (1 + minimum_margin_pct)).round(2)
  end
end
