class CreateRevenueRecognitionsJob < ApplicationJob
  queue_as :default

  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    RevenueRecognitionService.new(invoice).call
    Rails.logger.info "Created revenue recognitions for Invoice ##{invoice.number}"
  end
end
