class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def vamos
    # in production today will be the current day,
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # today = Date.today  + 1
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_by(date: today)
    @subscriptions = Subscription.active_subs_for(@today)
    @count_skip_subscriptions = Subscription.count_skip_subs_for(@today)
    # @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @subscriptions.select { |subscription| subscription.collections.last&.needs_bags }

    @hours_worked = @drivers_day.hours_worked unless @drivers_day.end_time.nil?
    @new_customers = @subscriptions.select { |subscription| subscription.collections.last&.new_customer == true }
  end

  def home

  end

  def collection
    @subscription = current_user.current_sub

  end

  def kiki
  end

  def welcome
    @subscription = current_user.current_sub
    # @subscription.set_collection_day
    # raise
    @subscription.save!
  end

end
