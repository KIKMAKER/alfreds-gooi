class SuburbsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @suburb = Suburb.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @suburb.waitlist? || @suburb.active?

    if @suburb.waitlist?
      @standard_og = Product.find_by(title: "Standard 6 month OG subscription")
      @xl_og = Product.find_by(title: "XL 6 month OG subscription")
    else
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
