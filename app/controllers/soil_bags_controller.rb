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
  def claim
    @collection.update!(soil_bag: 1) unless @collection.soil_bag_claimed?
    render :claimed
  end

  private

  def set_collection
    @collection = Collection.find_by_soil_bag_token!(params[:token])
  rescue ActiveRecord::RecordNotFound
    render :invalid, status: :not_found
  end
end
