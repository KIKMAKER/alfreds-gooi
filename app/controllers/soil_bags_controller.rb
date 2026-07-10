# frozen_string_literal: true

# Promotional soil bag giveaway. Customers get a signed per-collection link over
# WhatsApp (see Admin::BulkMessagesController) and claim a free bag for the
# collection that link was generated for. No login, no Order, no Invoice — the
# only side effect is setting soil_bag on that one collection.
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
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    render :invalid, status: :not_found
  end
end
