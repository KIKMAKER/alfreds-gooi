class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :story ]

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
    @collections.joins(:subscription)
                .order('subscriptions.collection_order')
                .each_with_index do |collection, index|
                  collection.update(position: index + 1) # Set position starting from 1
                end
  end

  def manage
    # Rails.logger.info "INFO: Testing logging in production."
    # Rails.logger.debug "DEBUG: Testing detailed logging in production."
    # Rails.logger.error "ERROR: Testing error logging in production."
    @subscription = current_user.current_sub
    @next_collection = @subscription.collections.where('date >= ?', Date.today).order(date: :asc).first
    @days_left = @subscription.remaining_collections.to_i if @subscription.start_date
    @unpaid_invoice = @subscription.invoices.find_by(paid: false)
    @all_collections = current_user.collections.order(date: :desc)
  end

  def welcome
    @subscription = current_user.current_sub
    merchant_reference = params[:merchantReference]
    if merchant_reference.present?
      # Fetch payments (this can be refactored into a service)
      payments = fetch_snapscan_payments(merchant_reference)

      # Check for a successful payment
      successful_payment = payments.find { |payment| payment["status"] == "completed" }

      if successful_payment
        handle_successful_payment(successful_payment)
        flash[:notice] = "Payment received! Your subscription is now active."
      else
        flash[:alert] = "No successful payment found for this subscription."
      end
    else
      flash[:alert] = "No merchant reference provided."
    end

  end

  def story
  end

  private

  def fetch_snapscan_payments(merchant_reference)
    # Example: Replace with actual SnapScan API fetch logic
    api_key = ENV['SNAPSCAN_API_KEY']
    service = SnapscanService.new(api_key)
    payments = service.fetch_payments
    payments.select { |payment| payment["merchantReference"] == merchant_reference }
  end

  def handle_successful_payment(successful_payment)
    # Find the user and subscription by merchant reference
    subscription = Subscription.find_by(customer_id: successful_payment["merchantReference"])
    return unless subscription
    last_invoice = @subscription.invoices.order(created_at: :desc).first
    # Update subscription and mark the last invoice as paid
    if last_invoice && last_invoice.total_amount.to_i == successful_payment["totalAmount"].to_i
      last_invoice.update!(paid: true)
      subscription.update!(status: 'active', start_date: subscription.calculate_next_collection_day)
    end
  end

end
