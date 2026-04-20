class DriverMessagesController < ApplicationController
  before_action :authenticate_user!

  def index
    @collection_day = params[:collection_day].presence
    @message        = params[:message].presence
    @recipients     = []
    @collection_date = nil

    if @collection_day.present?
      @collection_date = next_date_for(@collection_day)

      if @collection_date
        Collection
          .where(date: @collection_date, skip: false)
          .includes(subscription: :contacts)
          .each do |collection|
            sub = collection.subscription
            sub.contacts.can_receive_whatsapp.order(:is_primary => :desc, :first_name => :asc).each do |contact|
              @recipients << { contact: contact, subscription: sub, collection: collection }
            end
          end
      end
    end
  end

  private

  def next_date_for(day_name)
    target_wday = Date::DAYNAMES.index(day_name.to_s.titleize)
    return nil unless target_wday

    today      = Date.today
    days_ahead = (target_wday - today.wday) % 7
    days_ahead = 7 if days_ahead.zero? # always the NEXT occurrence, not today
    today + days_ahead
  end

  def personalize(message, contact, subscription, collection_date)
    {
      '{first_name}'      => contact.first_name.to_s,
      '{collection_day}'  => subscription.collection_day&.titleize.to_s,
      '{collection_date}' => collection_date.strftime('%A, %-d %B')
    }.reduce(message) { |msg, (token, value)| msg.gsub(token, value) }
  end
  helper_method :personalize
end
