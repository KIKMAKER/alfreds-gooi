# frozen_string_literal: true

# Tokenised "skip my next collection" link. Customers get a short per-collection
# code over WhatsApp (see Admin::BulkMessagesController) and skip that collection
# without logging in. Mirrors SoilBagsController — the only side effect is
# marking the one collection the code was minted for as skipped.
#
# The logged-in equivalent is CustomersController#skipme.
class SkipsController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :set_collection

  # GET — safe. WhatsApp fetches link previews, and skipping is consequential, so
  # this only ever shows a confirm page; the write happens on POST.
  def show; end

  # POST — the customer has confirmed. mark_skipped! sends the skip email and is
  # a no-op (returns false) if the collection is already skipped, so pressing
  # twice is harmless. Redirect so Turbo shows the result (see SoilBagsController).
  def create
    @collection.mark_skipped!(reason: "skipme_token") unless @collection.skip?
    redirect_to skip_path(@collection.skip_token),
                status: :see_other,
                flash: { just_skipped: true }
  end

  private

  def set_collection
    @collection = Collection.find_by_skip_token!(params[:token])
  rescue ActiveRecord::RecordNotFound
    render :invalid, status: :not_found
  end
end
