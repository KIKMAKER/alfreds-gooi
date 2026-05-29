class JourneyController < ApplicationController
  skip_before_action :authenticate_user!
  layout "journey"

  def show
    @user = User.find_by!(journey_token: params[:token])

    # ── Reuse existing User lifetime methods ──────────────────────────────
    @stat_total_litres      = @user.lifetime_litres
    @stat_input_kg          = @user.lifetime_input_kg.round(1)
    @stat_co2e_kg           = @user.lifetime_co2e_kg
    @stat_total_collections = @user.total_collections

    # Consistency rate: calculated here (not via User#consistency_rate) because
    # that method divides by total_weeks, assuming 1 collection/week — which
    # gives 200%+ for multi-collection-per-week commercial accounts.
    # Instead: sum expected collections per subscription (elapsed weeks ×
    # collections_per_week), then divide actual non-skipped collections by that.
    @stat_consistency_rate = journey_consistency_rate(@user)

    # ── Derived display stats ─────────────────────────────────────────────
    # Average car emits ~0.12 kg CO₂e per km
    @stat_km_equivalent = (@stat_co2e_kg / 0.12).round

    # ── Dates / duration ──────────────────────────────────────────────────
    first_sub = @user.subscriptions.order(:start_date).first
    @stat_start_date    = first_sub&.start_date&.to_date
    @stat_months_active = @stat_start_date ?
      [((Date.current - @stat_start_date).to_f / 30.44).ceil, 1].max : nil

    # ── Financial ─────────────────────────────────────────────────────────
    @stat_total_paid = Invoice
      .joins(:subscription)
      .where(subscriptions: { user_id: @user.id })
      .where(paid: true)
      .sum(:total_amount)

    # Cost per collection: calculated per subscription using the contracted
    # rate (contract_total / expected collections over the full term) rather
    # than paid-to-date / collected-to-date, which overstates cost for active
    # contracts where future collections haven't happened yet.
    # Expected collections = duration_months * 4.33 weeks/month * collections_per_week
    subs = @user.subscriptions.where.not(status: :pending)
    rate_estimates = subs.filter_map do |s|
      next unless s.contract_total&.positive?
      weeks = (s.duration || 6) * 4.33
      expected = (weeks * (s.collections_per_week || 1)).round
      next unless expected > 0
      s.contract_total / expected
    end

    @stat_cost_per_collection = if rate_estimates.any?
      (rate_estimates.sum / rate_estimates.size).round
    elsif @stat_total_collections > 0
      # Fallback for non-monthly-invoiced subs: actual paid / actual collected
      (@stat_total_paid / @stat_total_collections).round
    else
      0
    end

    # Flag whether any subscriptions are still active — used in the view
    # to qualify the label as "estimated" vs confirmed
    @has_active_subscription = subs.any? { |s| %w[active pause].include?(s.status) }

    # ── Display name: prefer business_profile name, fall back to first name ─
    business_name = @user.subscriptions
                         .filter_map { |s| s.business_profile&.business_name }
                         .first
    @display_name = business_name.presence || @user.first_name
  end

  private

  # Returns a consistency percentage that correctly handles subscriptions
  # with collections_per_week > 1. For each non-pending subscription, the
  # expected collection count is: elapsed_weeks × collections_per_week.
  # "Elapsed" means the full duration for completed subs, or start→today
  # for active/paused ones. The rate is capped at 100 — paused weeks can
  # push the actual count above expected briefly.
  def journey_consistency_rate(user)
    today = Date.current
    expected_total = 0.0

    user.subscriptions.where.not(status: :pending).each do |s|
      sub_start = s.start_date&.to_date
      next unless sub_start

      sub_end = case s.status
                when "completed", "legacy" then s.end_date&.to_date || today
                else today
                end

      elapsed_weeks = [(sub_end - sub_start).to_f / 7.0, 0].max
      expected_total += elapsed_weeks * (s.collections_per_week || 1)
    end

    return 0 if expected_total.zero?

    actual = user.collections.where(skip: false).where("date <= ?", today).count
    [((actual.to_f / expected_total) * 100).round, 100].min
  end
end
