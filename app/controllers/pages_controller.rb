class PagesController < ApplicationController
  # skip_before_action :authenticate_user!, only: [ :home ]

  def home
    # in production today will be the current day,
    # today = Date.today.strftime("%A")
    # but in testing I want to be able to test the view for a given day
    today = "Wednesday"
    @subscriptions = Subscription.where(collection_day: today).order(:collection_order)
    @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last.needs_bags }
  end
end
