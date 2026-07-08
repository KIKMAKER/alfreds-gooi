class CreateRevenueRecognitionsJob < ApplicationJob
  queue_as :default

  # Legacy job name kept so any enqueued jobs survive the deploy that
  # introduced SyncRevenueRecognitionsJob. Do not enqueue this directly.
  def perform(invoice_id)
    SyncRevenueRecognitionsJob.perform_now(invoice_id)
  end
end
