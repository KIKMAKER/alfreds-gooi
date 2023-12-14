class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @subscriptions = Subscription.where(collection_day: Date.today.strftime("%A")).order(:collection_order)
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last.skip == true }
  end
end
