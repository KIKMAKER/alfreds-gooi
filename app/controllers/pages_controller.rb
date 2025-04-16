class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :story ]

  def home
    @discount_code = params[:discount]
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
    @subscription = current_user.current_sub
    if @subscription.start_date
      @days_left = @subscription.remaining_collections.to_i
    else
      @subscription.update!(start_date: @subscription.suggested_start_date)
      @days_left = @subscription.remaining_collections.to_i
    end
    @next_collection = @subscription.collections.where('date >= ?', Date.today).order(date: :asc).first

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


  def referrals
    @referral_code = current_user.referral_code
    @referrals = current_user.referrals_as_referrer.where(status: "completed")
    @referral_count = @referrals.count
  end

  def story
  end

  private

  def fetch_snapscan_payments(merchant_reference)
    # Example: Replace with actual SnapScan API fetch logic
    api_key = ENV['SNAPSCAN_API_KEY']
    service = Snapscan::ApiClient.new(api_key)
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
      subscription.update!(status: 'active', start_date: subscription.suggested_start_date)
    end
  end

end
