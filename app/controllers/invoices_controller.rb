class InvoicesController < ApplicationController

  def new
    @subscription = Subscription.find(params[:id])
    @invoice = Invoice.new
  end
  def show
    @subscription = Subscription.find(params[:subscription_id])
    @invoice = @subscription.invoices.first
  end
end
