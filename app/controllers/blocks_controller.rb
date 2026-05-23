class BlocksController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @block = Block.find_by!(slug: params[:slug])

    # Pre-compute stats so the view reads variables, never calls methods twice.
    @stat_week_l          = @block.actual_volume_this_week_l
    @stat_month_l         = @block.actual_volume_this_month_l
    @stat_lifetime_l      = @block.lifetime_volume_l
    @stat_expected_l      = @block.expected_weekly_volume_l
    @estimated_households = @block.estimated_contributing_households
  end
end
