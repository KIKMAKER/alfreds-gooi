class SuburbsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @active_suburbs = Suburb.active.order(:name)
    # Suburb#waitlist? (overridden on the model) also requires launch_date to
    # be present — mirrored here in SQL so this list matches exactly what
    # #show will actually render instead of 404 on.
    @waitlist_suburbs = Suburb.where(status: :waitlist).where.not(launch_date: nil).order(:name)
    @target_suburbs = Suburb.target.order(:name)
  end

  def show
    @suburb = Suburb.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @suburb.waitlist? || @suburb.active? || @suburb.target?

    if @suburb.waitlist?
      @standard_og = Product.find_by(title: "Standard 6 month OG subscription")
      @xl_og = Product.find_by(title: "XL 6 month OG subscription")
    elsif @suburb.active?
      active_subscriptions = @suburb.subscriptions.active.to_a
      @household_count = active_subscriptions.count
      # Estimated, same approach Block/SuburbSpotlight already use — there's no
      # per-suburb weighed total (buckets are only weighed at the drivers_day
      # level, with no link back to which suburb they came from).
      total_litres = active_subscriptions.sum { |s| s.total_litres.to_i }
      week_litres = active_subscriptions.sum { |s| s.total_litres_between(Date.current.beginning_of_week, Date.current.end_of_week).to_i }
      @impact_total_kg = (total_litres * Block::DENSITY_KG_PER_L).round
      @impact_kg_this_week = (week_litres * Block::DENSITY_KG_PER_L).round
    end
  end
end
