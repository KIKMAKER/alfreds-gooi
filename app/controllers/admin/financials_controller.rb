class Admin::FinancialsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def dashboard
    @date_range = parse_date_range(params[:range] || 'this_month')

    # Get financial metrics for the date range
    start_year = @date_range.first.year
    start_month = @date_range.first.month
    end_year = @date_range.last.year
    end_month = @date_range.last.month

    @metrics = if start_year == end_year
                 # Same year - simple month range
                 FinancialMetric.where(year: start_year, month: start_month..end_month)
               else
                 # Spans multiple years
                 FinancialMetric.where(
                   "(year = ? AND month >= ?) OR (year > ? AND year < ?) OR (year = ? AND month <= ?)",
                   start_year, start_month, start_year, end_year, end_year, end_month
                 )
               end.order(:year, :month)

    # Aggregate totals
    @total_revenue = @metrics.sum(:recognized_revenue)
    @total_expenses = @metrics.sum(:total_expenses)
    @gross_profit = @metrics.sum(:gross_profit)
    @net_profit = @metrics.sum(:net_profit)

    # Month-over-month change
    @mom_revenue_change = calculate_mom_change

    # Expense breakdown
    @expense_breakdown = {
      cogs: @metrics.sum(:cogs_total),
      operational: @metrics.sum(:operational_total),
      fixed: @metrics.sum(:fixed_total),
      marketing: @metrics.sum(:marketing_total),
      admin: @metrics.sum(:admin_total),
      other: @metrics.sum(:other_total)
    }

    # Revenue forecasting
    @forecast = RevenueForecaster.new.forecast
  end

  def chart_data
    type = params[:type]
    data = case type
           when 'revenue-trend'
             revenue_trend_data
           when 'expense-breakdown'
             expense_breakdown_data
           else
             {}
           end

    render json: data
  end

  private

  def require_admin
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin?
  end

  def parse_date_range(range_param)
    case range_param
    when 'this_month'
      Date.current.beginning_of_month..Date.current.end_of_month
    when 'last_month'
      1.month.ago.beginning_of_month..1.month.ago.end_of_month
    when 'this_quarter'
      Date.current.beginning_of_quarter..Date.current.end_of_quarter
    when 'this_year'
      Date.current.beginning_of_year..Date.current.end_of_year
    else
      Date.current.beginning_of_month..Date.current.end_of_month
    end
  end

  def calculate_mom_change
    current_month = Date.current.beginning_of_month
    last_month = 1.month.ago.beginning_of_month

    current_metric = FinancialMetric.find_by(year: current_month.year, month: current_month.month)
    previous_metric = FinancialMetric.find_by(year: last_month.year, month: last_month.month)

    return 0 unless current_metric && previous_metric
    return 0 if previous_metric.recognized_revenue.zero?

    change = ((current_metric.recognized_revenue - previous_metric.recognized_revenue) /
              previous_metric.recognized_revenue * 100).round(2)

    change
  end

  def revenue_trend_data
    metrics = FinancialMetric.recent(12).reverse

    {
      labels: metrics.map(&:period_label),
      datasets: [
        {
          label: 'Revenue',
          data: metrics.map(&:recognized_revenue),
          borderColor: 'rgb(75, 192, 192)',
          tension: 0.1
        }
      ]
    }
  end

  def expense_breakdown_data
    current_month = Date.current
    metric = FinancialMetric.find_by(year: current_month.year, month: current_month.month)

    return {} unless metric

    {
      labels: ['COGS', 'Operational', 'Fixed', 'Marketing', 'Admin', 'Other'],
      datasets: [
        {
          label: 'Expenses',
          data: [
            metric.cogs_total,
            metric.operational_total,
            metric.fixed_total,
            metric.marketing_total,
            metric.admin_total,
            metric.other_total
          ],
          backgroundColor: [
            'rgb(255, 99, 132)',
            'rgb(54, 162, 235)',
            'rgb(255, 205, 86)',
            'rgb(75, 192, 192)',
            'rgb(153, 102, 255)',
            'rgb(201, 203, 207)'
          ]
        }
      ]
    }
  end
end
