class CustomersController < ApplicationController
  def subscriptions
    @subscriptions = current_user.subscriptions.order(created_at: :desc)
  end

  def manage
    @subscriptions = current_user.subscriptions.where(status: [:active, :pending]).order(created_at: :asc)
    @subscription = @subscriptions.first || current_user.current_sub
    @commercial_inquiries = current_user.commercial_inquiries.order(created_at: :desc)

    # Check if user has no subscriptions at all
    if current_user.subscriptions.empty?
      # User created account but never completed signup
      @no_subscription = true
      return
    end

    # Has past subscriptions but none active or pending
    if @subscriptions.none?
      @lapsed = true
      return
    end

    # Check for unpaid invoices across all subscriptions
    @unpaid_invoice = current_user.invoices.find_by(paid: false)

    # For single subscription (legacy flow)
    if @subscriptions.count == 1 && @subscription
      if @subscription.start_date
        @days_left = @subscription.remaining_collections.to_i
      else
        @subscription.update!(start_date: @subscription.suggested_start_date)
        @days_left = @subscription.remaining_collections.to_i
      end
      @next_collection = @subscription.collections.where('date >= ?', Date.today).order(date: :asc).first
      @start_date = @subscription.start_date.strftime('%b %Y')
    elsif @subscriptions.any?
      @days_left = 0
      @start_date = current_user.subscriptions.order(created_at: :asc).first&.start_date&.strftime('%b %Y')
    else
      @days_left = 0
      @start_date = nil
    end

    @recent_collections = current_user.collections.order(date: :desc).limit(5) if current_user.subscriptions.any?

    # Show referral code prompt if code was captured but no Referral record was created
    if current_user.referred_by_code.present? && current_user.referrals_as_referee.none?
      @orphaned_referral_code = current_user.referred_by_code
    end
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


  def my_stats
    @start_date = current_user.subscriptions.order(created_at: :asc).first&.start_date&.strftime('%b %Y')
    @recent_collections = current_user.collections.order(date: :desc).limit(5)
    @lifetime_litres = current_user.lifetime_litres.round(0)
    @lifetime_compost_kg = current_user.lifetime_compost_kg
    @lifetime_co2e_kg = current_user.lifetime_co2e_kg
    @total_collections = current_user.collections.where(skip: false).count
    @skipped_count = current_user.collections.where(skip: true).count
    @total_bags = current_user.lifetime_bags.to_i
    @streak = current_user.current_streak
    @consistency = current_user.consistency_rate
  end

  def referrals
    # Check if user has a subscription - need one to access referrals
    if current_user.subscriptions.empty?
      @no_subscription = true
      return
    end

    @referral_code = current_user.referral_code
    @referrals = current_user.referrals_as_referrer.where(status: "completed")
    @referral_count = @referrals.count
    share_url = "www.gooi.me/?referral=#{@referral_code}"
    @message = "Hey! I've been using a service called gooi to send my food scraps to a farm instead of to the landfill. It's a simple change with a huge impact on the planet. The team is trying to grow , and I have a referral code that will get you 15% off - just sign up using this link: #{share_url}"
    encoded_message = URI.encode_www_form_component(@message)
    @whatsapp_link = "https://wa.me/?text=#{encoded_message}"
  end

  def skipme
    # raise
    @subscription = current_user.subscriptions.where(status: 'active').order(:created_at).last

    # Find the next upcoming collection (any day from today onwards)
    collection = @subscription&.collections&.where('date >= ?', Date.current).order(:date).first

    return redirect_to manage_path, notice: "No subscription with next collction found." unless @subscription && collection

    # Determine the message based on when the collection is
    days_until = (collection.date - Date.current).to_i
    date_text = case days_until
                when 0 then 'today'
                when 1 then 'tomorrow'
                else "on #{collection.date.strftime('%A, %b %d')}"
                end

    if collection.mark_skipped!(by: current_user, reason: "skipme")
      @note = "Success!\n We'll skip you #{date_text}"
    else
      @note = "Something went wrong, please manually skip, or whatsapp Alfred"
    end
  end

  def submit_referral_code
    code = params[:referral_code]&.strip&.upcase

    if code.blank?
      redirect_to manage_path, alert: "Please enter a referral code." and return
    end

    if code == current_user.referral_code
      redirect_to manage_path, alert: "You can't use your own referral code." and return
    end

    referrer = User.find_by(referral_code: code)
    unless referrer
      redirect_to manage_path, alert: "We couldn't find anyone with that referral code. Double-check and try again." and return
    end

    if current_user.referrals_as_referee.exists?
      redirect_to manage_path, notice: "Your referral is already registered." and return
    end

    current_user.update!(referred_by_code: code)

    # If subscription is already active, complete the referral immediately
    status = current_user.subscriptions.active.any? ? :completed : :pending
    Referral.create!(
      subscription: current_user.current_sub,
      referee: current_user,
      referrer: referrer,
      status: status
    )

    redirect_to manage_path, notice: "Referral code applied! #{referrer.first_name} will get their reward on their next subscription."
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
