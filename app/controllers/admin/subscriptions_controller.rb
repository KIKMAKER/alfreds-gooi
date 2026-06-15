class Admin::SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_driver

  def new
    @user = User.find(params[:user_id])

    if params[:quotation_id].present?
      quotation = Quotation.find(params[:quotation_id])
      @subscription = Subscription.new(
        plan:                   :Commercial,
        duration:               quotation.duration_months,
        bucket_size:            quotation.inferred_bucket_size,
        buckets_per_collection: quotation.buckets_per_collection,
        collections_per_week:   quotation.effective_collections_per_week,
        title:                  quotation.prospect_company.presence || quotation.customer_name
      )
      @quotation = quotation
    else
      @subscription = Subscription.new
    end
  end

  def create
    @user = User.find(params[:user_id])
    @subscription = @user.subscriptions.build(subscription_params)
    @subscription.status   = :pending
    @subscription.is_paused = true

    if @subscription.save
      # Auto-create satellite subscription if a second collection day was specified
      if params[:second_collection_day].present?
        @user.subscriptions.create!(
          plan:                    @subscription.plan,
          duration:                @subscription.duration,
          street_address:          @subscription.street_address,
          suburb:                  @subscription.suburb,
          apartment_unit_number:   @subscription.apartment_unit_number,
          bucket_size:             @subscription.bucket_size,
          buckets_per_collection:  @subscription.buckets_per_collection,
          collections_per_week:    @subscription.collections_per_week,
          collection_day:          params[:second_collection_day],
          title:                   "#{@subscription.title} (#{params[:second_collection_day]})",
          status:                  :pending,
          is_paused:               true,
          primary_subscription_id: @subscription.id
        )
      end

      quotation = Quotation.find_by(id: params[:quotation_id]) if params[:quotation_id].present?
      @subscription.update_column(:quotation_id, quotation.id) if quotation

      referee = User.find_by(referral_code: @subscription.referral_code) if @subscription.referral_code.present?
      InvoiceBuilder.new(
        subscription: @subscription,
        is_new:       @subscription.is_new_customer,
        referee:      referee,
        quotation:    quotation
      ).call
      CreateFirstCollectionJob.perform_now(@subscription) if @subscription.once_off?
      redirect_to admin_user_path(@user), notice: "Subscription created and invoice sent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def change_plan
    @subscription = Subscription.find(params[:id])
    new_plan = params[:new_plan]

    unless %w[Standard XL].include?(new_plan)
      return redirect_to admin_subscription_path(@subscription), alert: "Invalid plan selection."
    end

    result = Subscriptions::ChangePlan.new(@subscription, new_plan).call

    if result.success
      redirect_to admin_subscription_path(@subscription), notice: "Plan changed to #{new_plan}. Invoice updated."
    else
      redirect_to admin_subscription_path(@subscription), alert: result.error
    end
  end

  def show
    @subscription = Subscription.joins(:user).find(params[:id])
    @next_subscription = @subscription.user.subscriptions.last if @subscription.completed?
    @collections = @subscription.collections
    @total_collections = @subscription.total_collections
    @skipped_collections = @subscription.skipped_collections
    @successful_collections = @total_collections - @skipped_collections
    @total_bags = @subscription.total_bags
    @total_buckets = @subscription.total_buckets
    @bags_last_month = @subscription.total_bags_last_n_months(1)
    @bags_last_three_months = @subscription.total_bags_last_n_months(3)
    @bags_last_six_months = @subscription.total_bags_last_n_months(6)
    @buckets_last_month = @subscription.total_buckets_last_n_months(1).to_i
    @buckets_last_three_months = @subscription.total_buckets_last_n_months(3).to_i
    @buckets_last_six_months = @subscription.total_buckets_last_n_months(6).to_i
    @total_litres = @subscription.total_litres
    @litres_last_month = @subscription.total_litres_last_n_months(1)
    @litres_last_three_months = @subscription.total_litres_last_n_months(3)
    @avg_litres_per_collection = @subscription.avg_litres_per_collection
    @allowed_litres = @subscription.allowed_litres_per_collection
    scope = @subscription.collections
                       .where(skip: false)
                       .where.not(updated_at: nil, time: nil)
    avg_secs = scope.where.not(time: nil)
                    .average(Arel.sql(
                      "EXTRACT(EPOCH FROM ((time AT TIME ZONE 'Africa/Johannesburg') - DATE_TRUNC('day', (time AT TIME ZONE 'Africa/Johannesburg'))))"
                    )).to_f

    @avg_time_sample     = scope.where.not(time: nil).count
    @avg_collection_time = @avg_time_sample.positive? ? (Time.zone.now.beginning_of_day + avg_secs).strftime('%H:%M') : nil

    if %w[Standard XL].include?(@subscription.plan) && !@subscription.completed? && !@subscription.legacy?
      target_plan = @subscription.Standard? ? "XL" : "Standard"
      @change_plan_target         = target_plan
      @change_plan_target_product = Product.find_by(title: "#{target_plan} #{@subscription.duration} month subscription")
      @change_plan_current_product = Product.find_by(id: @subscription.subscription_product_id)
      @change_plan_original_invoice = @subscription.invoices.order(:created_at).first
    end
  end

  def update_monthly_billing
    @subscription = Subscription.find(params[:id])
    if @subscription.update(monthly_billing_params)
      redirect_to admin_subscription_path(@subscription),
                  notice: "Monthly billing settings updated."
    else
      redirect_to admin_subscription_path(@subscription),
                  alert: "Could not save: #{@subscription.errors.full_messages.to_sentence}"
    end
  end

  def link_as_satellite
    @subscription = Subscription.find(params[:id])
    primary = @subscription.user.subscriptions.find_by(id: params[:primary_subscription_id])

    unless primary
      return redirect_to admin_subscription_path(@subscription), alert: "Parent subscription not found."
    end

    if primary.id == @subscription.id
      return redirect_to admin_subscription_path(@subscription), alert: "A subscription cannot be a satellite of itself."
    end

    @subscription.update!(primary_subscription_id: primary.id)
    redirect_to admin_subscription_path(@subscription),
                notice: "Linked as satellite of ##{primary.id} — #{primary.display_name}. This subscription will no longer generate its own invoices."
  end

  def unlink_satellite
    @subscription = Subscription.find(params[:id])
    @subscription.update!(primary_subscription_id: nil)
    redirect_to admin_subscription_path(@subscription),
                notice: "Satellite link removed. This subscription will now bill independently."
  end

  def generate_monthly_invoice
    @subscription = Subscription.find(params[:id])

    if !@subscription.monthly_invoicing?
      return redirect_to admin_subscription_path(@subscription),
                         alert: "This subscription does not use monthly invoicing."
    end

    if @subscription.satellite?
      return redirect_to admin_subscription_path(@subscription),
                         alert: "Satellites never generate invoices — trigger on the primary subscription."
    end

    if @subscription.next_invoice_date.nil?
      return redirect_to admin_subscription_path(@subscription),
                         alert: "No next_invoice_date set on this subscription."
    end

    if @subscription.next_invoice_date > Date.today
      return redirect_to admin_subscription_path(@subscription),
                         alert: "Invoice not due yet — next invoice date is #{@subscription.next_invoice_date.strftime('%d %b %Y')}."
    end

    invoice = MonthlyInvoiceService.new(@subscription).call

    if invoice
      redirect_to admin_subscription_path(@subscription),
                  notice: "Invoice ##{invoice.id} generated (R#{invoice.total_amount / 100}) and sent for approval."
    else
      redirect_to admin_subscription_path(@subscription),
                  alert: "Service ran but did not generate an invoice. Check subscription state."
    end
  rescue => e
    redirect_to admin_subscription_path(@subscription),
                alert: "Error generating invoice: #{e.message}"
  end

  RESENDABLE_EMAIL_TYPES = %w[welcome payment_received payment_prompt ad_hoc_nudge subscription_ending_soon].freeze

  def resend_email
    @subscription = Subscription.find(params[:id])
    email_type = params[:email_type]
    recipient  = params[:recipient_email]

    unless RESENDABLE_EMAIL_TYPES.include?(email_type)
      return redirect_to admin_subscription_path(@subscription), alert: "Unknown email type."
    end

    if recipient.blank? || recipient !~ URI::MailTo::EMAIL_REGEXP
      return redirect_to admin_subscription_path(@subscription), alert: "Please choose a valid recipient."
    end

    case email_type
    when "welcome"
      UserMailer.with(subscription: @subscription, to_email: recipient).welcome.deliver_now
      UserMailer.with(subscription: @subscription).sign_up_alert.deliver_now
    when "payment_received"
      SubscriptionMailer.with(subscription: @subscription, to_email: recipient, is_new: false).payment_received.deliver_now
      SubscriptionMailer.with(subscription: @subscription).payment_received_alert.deliver_now
    when "payment_prompt"
      SubscriptionMailer.with(subscription: @subscription, to_email: recipient).payment_prompt.deliver_now
      SubscriptionMailer.with(subscription: @subscription).payment_prompt_alert.deliver_now
    when "ad_hoc_nudge"
      SubscriptionMailer.with(subscription: @subscription).ad_hoc_nudge.deliver_now
      SubscriptionMailer.with(subscription: @subscription).ad_hoc_nudge_alert.deliver_now
    when "subscription_ending_soon"
      SubscriptionMailer.with(subscription: @subscription).subscription_ending_soon.deliver_now
      SubscriptionMailer.with(subscription: @subscription).subscription_ending_soon_alert.deliver_now
    end

    redirect_to admin_subscription_path(@subscription),
                notice: "#{email_type.humanize} email queued for #{recipient}."
  end

  private

  def subscription_params
    params.require(:subscription).permit(
      :plan, :duration, :start_date, :street_address, :suburb,
      :apartment_unit_number, :discount_code, :referral_code, :is_new_customer,
      :primary_subscription_id,
      :buckets_per_collection, :bucket_size, :collections_per_week,
      :collection_day, :title, :monthly_invoicing
    )
  end

  def monthly_billing_params
    params.require(:subscription).permit(
      :monthly_invoicing,
      :next_invoice_date,
      :monthly_subscription_amount,
      :monthly_volume_amount,
      :starter_kit_installment
    )
  end

  def require_admin_or_driver
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin? || current_user.driver?
  end
end
