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

  # Real average monthly litres over the last 3 *complete* calendar months,
  # computed live from actual collection data (not persisted — it's a fact
  # about the business, not a setting). Distinct from target_monthly_litres,
  # which is the admin's capacity assumption used for forward-looking
  # pricing. Deliberately excludes the current, still-in-progress month —
  # see month_to_date_litres/month_to_date_projected_litres for that —
  # since a partial month drags the average down and understates the true
  # run rate.
  def trailing_3mo_avg_litres
    range = self.class.complete_months_range(3)
    total = Collection.total_litres_between(range.first, range.last)
    (total / 3.0).round(1)
  end

  def month_to_date_litres
    Collection.total_litres_between(Date.current.beginning_of_month, Date.current)
  end

  # Straight-line projection of the current month's total, based on litres
  # collected so far and how far through the month today is.
  def month_to_date_projected_litres
    day = Date.current.day
    return month_to_date_litres.to_f if day.zero?
    (month_to_date_litres.to_f / day * Date.current.end_of_month.day).round(1)
  end

  # Start/end dates spanning the last `months` complete calendar months as
  # of `as_of` — i.e. excludes the current, still-in-progress month.
  def self.complete_months_range(months, as_of: Date.current)
    end_date = as_of.beginning_of_month - 1.day
    start_date = as_of.beginning_of_month - months.months
    start_date..end_date
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
