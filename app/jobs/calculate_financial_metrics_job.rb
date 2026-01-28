class CalculateFinancialMetricsJob < ApplicationJob
  queue_as :default

  def perform(year, month)
    FinancialMetricsCalculator.new(year, month).calculate
    Rails.logger.info "Calculated financial metrics for #{Date.new(year, month, 1).strftime('%B %Y')}"
  end
end
