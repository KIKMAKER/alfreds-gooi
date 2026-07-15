# frozen_string_literal: true
class SuburbSpotlightsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]

  # GET /suburb_spotlight?suburb=Sea+Point&month=2026-07
  def show
    suburb = Subscription::SUBURBS.include?(params[:suburb]) ? params[:suburb] : Subscription::SUBURBS.first
    month  = params[:month].present? ? Date.strptime(params[:month], "%Y-%m") : Date.current

    @spotlight = SuburbSpotlight.call(suburb: suburb, month: month)

    render layout: 'snapshot'
  rescue ArgumentError
    @spotlight = SuburbSpotlight.call(suburb: suburb, month: Date.current)
    render layout: 'snapshot'
  end
end
