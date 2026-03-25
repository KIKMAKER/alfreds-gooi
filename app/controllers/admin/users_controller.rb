# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:show, :edit, :update, :renew_last_subscription, :fix_subscription_boundaries, :collections, :nudge_pending]

  SUBS_COUNT_SQL = "(SELECT COUNT(*) FROM subscriptions WHERE subscriptions.user_id = users.id)".freeze
  LATEST_SUB_STATUS_SQL = "(SELECT status FROM subscriptions WHERE subscriptions.user_id = users.id ORDER BY created_at DESC LIMIT 1)".freeze

  SORTABLE_USER_COLS = {
    "name"              => "first_name",
    "email"             => "email",
    "last_login"        => "last_sign_in_at",
    "subs_count"        => SUBS_COUNT_SQL,
    "latest_sub_status" => LATEST_SUB_STATUS_SQL
  }.freeze

  def index
    @sort = SORTABLE_USER_COLS.key?(params[:sort]) ? params[:sort] : "name"
    @dir  = params[:dir] == "desc" ? "desc" : "asc"

    @users = User.includes(:subscriptions).order(Arel.sql("#{SORTABLE_USER_COLS[@sort]} #{@dir} NULLS LAST"))
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_create_params)
    @user.password = "password" # Default password

    if @user.save
      # Determine where to redirect based on next_action parameter
      case params[:next_action]
      when 'subscription'
        redirect_to new_subscription_path(user_id: @user.id),
                    notice: "User created! Now create their subscription."
      when 'drop_off'
        redirect_to admin_drop_off_sites_path,
                    notice: "Drop-off manager created! They can reset their password via email."
      else
        redirect_to admin_user_path(@user),
                    notice: "User created successfully."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @subscriptions = @user.subscriptions
                          .includes(:collections, :invoices)
                          .order(start_date: :desc)

    # Find who referred this user — only customers can be referrers
    code = @user.subscriptions.where.not(referral_code: [nil, '']).order(:created_at).first&.referral_code
    @referred_by = @user.referrals_as_referee.includes(:referrer).joins(:referrer).where(referrer: { role: :customer }).first&.referrer ||
                   User.customer.find_by(referral_code: code)

    # Calculate lifetime environmental impact stats
    @lifetime_litres = @user.lifetime_litres.round(0)
    @lifetime_compost_kg = @user.lifetime_compost_kg
    @lifetime_co2e_kg = @user.lifetime_co2e_kg
  end

  def edit

  end

  def update
    if @user.update(user_params)
      if @user.saved_change_to_phone_number? && @user.phone_number.present?
        Contact.where(subscription: @user.subscriptions, is_primary: true)
               .update_all(phone_number: @user.phone_number)
      end
      redirect_to admin_user_path(@user), notice: "User updated."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def renew_last_subscription
    result = Subscriptions::RenewalService.new(user: @user).call

    if result.success?
      # Create invoice for the new subscription
      invoice = InvoiceBuilder.new(
        subscription: result.subscription,
        og: @user.og || false,
        is_new: false
      ).call

      redirect_to admin_user_path(@user),
        notice: "Created subscription ##{result.subscription.id} and invoice ##{invoice.id}."
    else
      redirect_to admin_user_path(@user),
        alert: "Could not renew subscription: #{result.error}"
    end
  rescue StandardError => e
    redirect_to admin_user_path(@user),
      alert: "Error creating subscription/invoice: #{e.message}"
  end

  def pending
    @pending_users = User.joins(subscriptions: :invoices)
                         .where(subscriptions: { status: :pending }, invoices: { paid: false })
                         .select("users.*, MIN(invoices.issued_date) AS invoice_issued_date,
                                  MAX(invoices.total_amount) AS invoice_total,
                                  MIN(subscriptions.payment_reminder_sent_at) AS last_nudged_at")
                         .group("users.id")
                         .order(Arel.sql("MIN(invoices.issued_date) ASC"))
  end

  def nudge_pending
    subscription = @user.subscriptions.pending
                        .joins(:invoices)
                        .where(invoices: { paid: false })
                        .first

    if subscription
      SubscriptionMailer.with(subscription: subscription).ad_hoc_nudge.deliver_now
      SubscriptionMailer.with(subscription: subscription).ad_hoc_nudge_alert.deliver_now
      redirect_to pending_admin_users_path, notice: "Nudge sent to #{@user.first_name}."
    else
      redirect_to pending_admin_users_path, alert: "No pending subscription found for #{@user.first_name}."
    end
  end

  def nudge_all_pending
    subs = Subscription.pending
                       .joins(:invoices)
                       .where(invoices: { paid: false })
                       .distinct

    subs.each do |subscription|
      SubscriptionMailer.with(subscription: subscription).ad_hoc_nudge.deliver_now
      SubscriptionMailer.with(subscription: subscription).ad_hoc_nudge_alert.deliver_now
    end

    redirect_to pending_admin_users_path, notice: "Nudge sent to #{subs.count} pending customer#{'s' if subs.count != 1}."
  end

  def collections
    @collections = @user.collections
                        .includes(subscription: :user)
                        .order(date: :desc)
  end

  def fix_subscription_boundaries
    dry_run = params[:dry_run] == "1"
    result = Subscriptions::FixBoundariesService.new(user: @user, dry_run: dry_run).call

    if result.success?
      if dry_run
        @changes = result.changes
        render :fix_boundaries_preview
      else
        summary = result.changes.map do |c|
          "Sub ##{c[:subscription_id]}: end_date → #{c[:new_end_date].strftime('%d %b %Y')}, #{c[:reassigning]} collections reassigned" +
          (c[:next_sub_id] ? ", sub ##{c[:next_sub_id]} start → #{c[:next_sub_new_start_date]&.strftime('%d %b %Y')}" : "")
        end.join(" | ")
        redirect_to admin_user_path(@user), notice: summary.presence || "Nothing to fix."
      end
    else
      redirect_to admin_user_path(@user), alert: result.error
    end
  rescue StandardError => e
    redirect_to admin_user_path(@user), alert: "Error: #{e.message}"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    # Adjust according to your User model attributes
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :customer_id, :address)
  end

  def user_create_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :role)
  end

  def require_admin
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin?
  end
end
