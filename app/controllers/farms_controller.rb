class FarmsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @farms = DropOffSite.order(:name)
  end

  def show
    @farm = DropOffSite.find_by(slug: params[:slug]) || DropOffSite.find(params[:slug])
    @recent_events = @farm.drop_off_events.where(is_done: true).order(date: :desc).limit(10)
    # #served_suburbs (DropOffSite) only plucks names — need real records here
    # to link each one to its own /suburbs/:slug page.
    @served_suburbs = Suburb.active.where(collection_day: @farm.collection_day).order(:name)
  end
end
