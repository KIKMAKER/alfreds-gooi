class NudgePendingSubscriptionsJob < ApplicationJob
  queue_as :default

  STAGES = [
    { name: :day_3,  min: 3,  max: 6  },
    { name: :day_7,  min: 7,  max: 13 },
    { name: :day_14, min: 14, max: 17 }
  ].freeze

  def perform
    Subscription.pending
                .joins(:invoices)
                .where(invoices: { paid: false })
                .where.not(invoices: { issued_date: nil })
                .distinct
                .each do |subscription|
      invoice = subscription.invoices.where(paid: false).order(:issued_date).last
      next unless invoice&.issued_date

      days  = (Date.today - invoice.issued_date).to_i
      stage = STAGES.find { |s| days >= s[:min] && days <= s[:max] }
      next unless stage

      # Skip if we already sent a nudge within this stage's window
      if subscription.payment_reminder_sent_at
        next if subscription.payment_reminder_sent_at >= invoice.issued_date + stage[:min].days
      end

      SubscriptionMailer.with(subscription: subscription).payment_reminder(stage[:name]).deliver_now
      SubscriptionMailer.with(subscription: subscription).payment_reminder_alert(stage[:name]).deliver_now
      subscription.update_column(:payment_reminder_sent_at, Date.today)

      Rails.logger.info "Payment nudge (#{stage[:name]}) sent for sub ##{subscription.id}"
    end
  end
end
