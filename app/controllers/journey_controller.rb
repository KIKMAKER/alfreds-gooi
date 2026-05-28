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
    @stat_consistency_rate  = @user.consistency_rate

    # ── Derived display stats ─────────────────────────────────────────────
    # Average car emits ~0.12 kg CO₂e per km
    @stat_km_equivalent = (@stat_co2e_kg / 0.12).round

    # ── Dates / duration ──────────────────────────────────────────────────
    first_sub = @user.subscriptions.order(:start_date).first
    @stat_start_date    = first_sub&.start_date
    @stat_months_active = @stat_start_date ?
      [((Date.current - @stat_start_date).to_f / 30.44).ceil, 1].max : nil

    # ── Financial: sum paid invoices across ALL subscriptions ─────────────
    @stat_total_paid = Invoice
      .joins(:subscription)
      .where(subscriptions: { user_id: @user.id })
      .where(paid: true)
      .sum(:total_amount)
    @stat_cost_per_collection = @stat_total_collections > 0 ?
      (@stat_total_paid / @stat_total_collections).round : 0

    # ── Display name: prefer business_profile name, fall back to first name ─
    business_name = @user.subscriptions
                         .filter_map { |s| s.business_profile&.business_name }
                         .first
    @display_name = business_name.presence || @user.first_name
  end
end
