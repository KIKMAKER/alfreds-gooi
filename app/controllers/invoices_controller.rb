class InvoicesController < ApplicationController
  def show
    @subscription = Subscription.find(params[:subscription_id])
    @invoice = @subscription.invoices.first
  end
end
