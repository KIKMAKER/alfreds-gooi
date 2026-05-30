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

    # Only show per-collection rate when contract_total is available.
    # The fallback (paid / collected) is misleading for active contracts where
    # invoices cover future collections — R4440 paid / 13 done overstates cost.
    @stat_cost_per_collection = if rate_estimates.any?
      (rate_estimates.sum / rate_estimates.size).round
    end
    # nil means the view omits the per-collection line entirely

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

  # Consistency rate based on actual scheduled collection records.
  # Denominator = all past scheduled slots (done + skipped).
  # This avoids calendar arithmetic and start_date inaccuracies entirely —
  # if a collection was scheduled and done, it counts for you; if it was
  # skipped, it counts against. Future collections are excluded.
  # Works correctly regardless of collections_per_week or overlapping subs.
  def journey_consistency_rate(user)
    today = Date.current
    past_total = user.collections.where("date <= ?", today).count
    return 0 if past_total.zero?

    past_done = user.collections.where(skip: false).where("date <= ?", today).count
    [(past_done.to_f / past_total * 100).round, 100].min
  end
end
