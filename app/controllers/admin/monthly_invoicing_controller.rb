class Admin::MonthlyInvoicingController < Admin::BaseController
  def index
    @subscriptions = Subscription
      .where(monthly_invoicing: true, primary_subscription_id: nil)
      .where(status: %i[active pause])
      .includes(:user, :satellite_subscriptions, invoices: :invoice_items)
      .order(Arel.sql("next_invoice_date ASC NULLS LAST"))

    @overdue_count   = @subscriptions.count { |s| s.next_invoice_date&.< Date.today }
    @due_today_count = @subscriptions.count { |s| s.next_invoice_date == Date.today }
  end
end
