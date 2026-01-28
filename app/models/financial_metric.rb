class FinancialMetric < ApplicationRecord
  # Validations
  validates :year, :month, presence: true
  validates :month, inclusion: { in: 1..12 }
  validates :year, :month, uniqueness: { scope: :year, message: "metric already exists for this month" }

  # Scopes
  scope :for_year, ->(year) { where(year: year).order(:month) }
  scope :recent, ->(limit = 12) { order(year: :desc, month: :desc).limit(limit) }

  # Instance Methods
  def period_label
    Date.new(year, month, 1).strftime("%B %Y")
  end

  def profit_margin
    return 0 if recognized_revenue.zero?
    ((net_profit / recognized_revenue) * 100).round(2)
  end

  def gross_profit_margin
    return 0 if recognized_revenue.zero?
    ((gross_profit / recognized_revenue) * 100).round(2)
  end

  def expense_ratio
    return 0 if recognized_revenue.zero?
    ((total_expenses / recognized_revenue) * 100).round(2)
  end

  def month_over_month_growth
    previous_month = self.class.find_by(year: previous_month_year, month: previous_month_num)
    return nil unless previous_month&.recognized_revenue&.positive?

    ((recognized_revenue - previous_month.recognized_revenue) / previous_month.recognized_revenue * 100).round(2)
  end

  private

  def previous_month_year
    month == 1 ? year - 1 : year
  end

  def previous_month_num
    month == 1 ? 12 : month - 1
  end
end
