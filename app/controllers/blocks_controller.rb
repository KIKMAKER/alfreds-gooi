class BlocksController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @block = Block.find_by!(slug: params[:slug])

    # Pre-compute stats so the view reads variables, never calls methods twice.
    @stat_month_l         = @block.actual_volume_this_month_l
    @stat_lifetime_l      = @block.lifetime_volume_l
    @stat_expected_l      = @block.expected_weekly_volume_l
    @estimated_households = @block.estimated_contributing_households
    @collection_days_label = @block.collection_days_label

    # Show last week's figures if none of this block's collection days have
    # arrived yet in the current Mon–Sun week.
    earliest_collection_date_this_week = @block.collection_days.filter_map { |day_name|
      wday = Date::DAYNAMES.index(day_name)
      next unless wday
      offset = (wday - Date.current.beginning_of_week.wday) % 7
      Date.current.beginning_of_week + offset
    }.min

    if earliest_collection_date_this_week.nil? || Date.current >= earliest_collection_date_this_week
      @stat_week_l  = @block.actual_volume_this_week_l
      @week_label   = "This week"
    else
      @stat_week_l  = @block.actual_volume_last_week_l
      @week_label   = "Last week"
    end
  end
end
