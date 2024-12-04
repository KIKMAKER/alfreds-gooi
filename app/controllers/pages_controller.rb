class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :thestory ]

  def vamos
    # in production today will be the current day,
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # today = Date.today  + 1
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_by(date: today)
    @collections = @drivers_day.collections
    @skip_collections = @collections.where(skip: true)
    @new_customers = @collections.select { |collection| collection.new_customer == true }
    @count = @collections.count - @skip_collections.count - (@new_customers.any? ? @new_customers.count : 0)
    # @subscriptions = Subscription.active_subs_for(@today)
    # @count_skip_subscriptions = Subscription.count_skip_subs_for(@today)
    # @skip_subscriptions = @subscriptions.select { |subscription| subscription.collections.last&.skip == true }
    @bags_needed = @collections.select { |collection| collection.needs_bags }

    @hours_worked = @drivers_day.hours_worked unless @drivers_day.end_time.nil?
  end

  def home
  end
  def today
    today = Date.today
    # but in testing I want to be able to test the view for a given day
    # DEVELOPMENT
    # today = Date.today  + 1
    @today = today.strftime("%A")
    @drivers_day = DriversDay.find_or_create_by(date: today)
    # Fetch subscriptions for the day and eager load related collections (thanks chat)
    # @subscriptions = Subscription.active_subs_for(@today)
    @collections = @drivers_day.collections.includes(:subscription, :user).order(:order)
  end

  def thestory
  end

  def manage
    @subscription = current_user.current_sub

  end

  def welcome
    @subscription = current_user.current_sub
    # @subscription.set_collection_day
    # raise
    @subscription.save!
  end

end
