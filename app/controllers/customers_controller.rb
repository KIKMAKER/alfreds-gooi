class CustomersController < ApplicationController
  def subscriptions
    @subscriptions = current_user.subscriptions.order(created_at: :desc)
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
    @recent_collections = current_user.collections.order(date: :desc).limit(5)
  end

  def account
    @user = current_user
    @subscription = current_user.current_sub
  end

  def collections_history
    @per  = params.fetch(:per, 20).to_i.clamp(1, 100)
    @page = params.fetch(:page, 1).to_i

    scope = current_user.collections.order(date: :desc)
    @total = scope.count
    @collections = scope.offset((@page - 1) * @per).limit(@per)
    @total_pages = (@total.to_f / @per).ceil
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
    collection_day = current_user.current_sub.collection_day
    share_url = "alfred.gooi.me/?referral=#{@referral_code}"
    @message = "Hey! I've been using a service called gooi to send my food scraps to a farm instead of to the landfill. It's such a simple change with a huge impact on the planet. The team is trying to grow in this neighbourhood (they collect every #{collection_day}), and I have a referral code that will get you 15% off - just sign up using this link: #{share_url}"
    encoded_message = URI.encode_www_form_component(@message)
    @whatsapp_link = "https://wa.me/?text=#{encoded_message}"
  end

  def skipme
    target_dates = [Date.current, Date.current.tomorrow]
    @subscription = current_user.subscriptions.where(is_paused: false, status: 'active').order(:created_at).last
    collection = @subscription.collections.where(date: target_dates).order(:date).first

    return redirect_to manage_path, notice: "No active subscription found." unless @subscription && collection

    date = collection.date == Date.current ? 'today' : 'tomorrow'

    if collection.mark_skipped!(by: current_user, reason: "skipme")
      @note = "Success!\n We'll skip you #{date}"
    else
      @note = "Something went wrong, please manually skip, or whatsapp Alfred"
    end
  end

  private

  def fetch_snapscan_payments(merchant_reference)
    api_key = ENV['SNAPSCAN_API_KEY']
    service = Snapscan::ApiClient.new(api_key)
    payments = service.fetch_payments
    payments.select { |payment| payment["merchantReference"] == merchant_reference }
  end

  def handle_successful_payment(successful_payment)
    subscription = Subscription.find_by(customer_id: successful_payment["merchantReference"])
    return unless subscription
    last_invoice = @subscription.invoices.order(created_at: :desc).first
    if last_invoice && last_invoice.total_amount.to_i == successful_payment["totalAmount"].to_i
      last_invoice.update!(paid: true)
      subscription.update!(status: 'active', start_date: subscription.suggested_start_date)
    end
  end
end
