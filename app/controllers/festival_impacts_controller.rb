class FestivalImpactsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "festival_impact"

  def show
    @festival = FestivalEvent.find_by!(slug: params[:slug])
    @draft = !@festival.published?
    # Drafts are previewable by admins only; everyone else gets a plain 404.
    raise ActiveRecord::RecordNotFound if @draft && !current_user&.admin?

    @facts = @festival.impact.facts
  end
end
