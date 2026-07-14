class DriverMessagesController < ApplicationController
  before_action :authenticate_user!

  SKIP_PLACEHOLDER = "{skip_link}"

  def index
    @collection_day  = params[:collection_day].presence
    @message         = params[:message].presence
    @recipients      = []
    @collection_date = nil

    return if @collection_day.blank?

    @collection_date = next_date_for(@collection_day)
    return if @collection_date.nil?

    collections = Collection
                  .where(date: @collection_date, skip: false)
                  .includes(subscription: [:contacts, :user])
                  .to_a

    @skip_eligible_ids = CollectionSkipPolicy.eligible_collection_ids(collections)
    @recipients = collections.flat_map { |collection| recipients_for(collection) }
  end

  private

  # Build the recipient rows for one collection, each carrying the message
  # personalised for that customer (skip link resolved, or the skip invitation
  # removed for customers who shouldn't be asked).
  def recipients_for(collection)
    subscription = collection.subscription
    return [] if subscription.nil?

    message  = personalise(collection)
    contacts = subscription.contacts.can_receive_whatsapp.order(is_primary: :desc, first_name: :asc)

    if contacts.any?
      contacts.map do |contact|
        recipient("c#{contact.id}", "#{contact.first_name} #{contact.last_name}".strip,
                  contact.formatted_phone, subscription.suburb, message)
      end
    elsif subscription.user&.phone_number.present?
      user = subscription.user
      [recipient("u#{user.id}", user.first_name.to_s, user.phone_number, subscription.suburb, message)]
    else
      []
    end
  end

  def recipient(id, name, phone, suburb, message)
    { id: id, name: name, phone: phone.to_s, suburb: suburb, message: message }
  end

  # Resolve {skip_link} for this collection. Eligible customers get a real skip
  # URL (minting the token on demand); everyone else has the whole line the
  # placeholder sits on removed, so new and once-off customers are never asked.
  # Minting writes, so it only happens when the message actually uses the token.
  def personalise(collection)
    return @message unless @message&.include?(SKIP_PLACEHOLDER)

    if @skip_eligible_ids.include?(collection.id)
      @message.gsub(SKIP_PLACEHOLDER, skip_url(collection.ensure_skip_token!))
    else
      @message.lines.reject { |line| line.include?(SKIP_PLACEHOLDER) }.join.strip
    end
  end

  def next_date_for(day_name)
    target_wday = Date::DAYNAMES.index(day_name.to_s.titleize)
    return nil unless target_wday

    today      = Date.today
    days_ahead = (target_wday - today.wday) % 7
    days_ahead = 7 if days_ahead.zero? # always the NEXT occurrence, not today
    today + days_ahead
  end
end
