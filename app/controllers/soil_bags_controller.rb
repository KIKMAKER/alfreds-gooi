# frozen_string_literal: true

# Promotional soil bag giveaway. Customers get a short per-collection claim code
# over WhatsApp (see Admin::BulkMessagesController) and claim a free bag for the
# collection that code was minted for. No login, no Order, no Invoice — the only
# side effect is setting soil_bag on that one collection.
#
# The token is a bearer credential, but the worst it buys is a free bag of
# compost delivered to the token holder's own address.
class SoilBagsController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :set_collection

  # GET — safe. WhatsApp fetches link previews, so this must not write anything.
  def show; end

  # POST — the customer has actually pressed the button.
  #
  # Redirect rather than render: button_to submits through Turbo, which only
  # swaps the page on a redirect. A rendered 200 gets discarded, so the customer
  # sees nothing happen and clicks again. Post/Redirect/Get also means a refresh
  # re-shows the result instead of re-submitting.
  def claim
    @collection.update!(soil_bag: 1) unless @collection.soil_bag_claimed?
    redirect_to soil_bag_path(@collection.soil_bag_token),
                status: :see_other,
                flash: { just_claimed: true }
  end

  private

  def set_collection
    @collection = Collection.find_by_soil_bag_token!(params[:token])
  rescue ActiveRecord::RecordNotFound
    render :invalid, status: :not_found
  end
end
