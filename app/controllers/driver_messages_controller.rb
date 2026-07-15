class DriverMessagesController < ApplicationController
  before_action :authenticate_user!

  SKIP_PLACEHOLDER = "{skip_link}"
  NAME_PLACEHOLDER = "{first_name}"

  def index
    @collection_day  = params[:collection_day].presence
    @recipients      = []
    @collection_date = nil

    return if @collection_day.blank?

    @collection_date = next_date_for(@collection_day)
    return if @collection_date.nil?

    collections = Collection
                  .where(date: @collection_date, skip: false)
                  .includes(subscription: [:contacts, :user])
                  .to_a

    @segments  = CollectionSegment.for_collections(collections)
    @templates = DriverMessageTemplate.bodies_by_segment
    @recipients = collections.flat_map { |collection| recipients_for(collection) }
  end

  private

  # Build the recipient rows for one collection. Each recipient's message comes
  # from the template for that customer's segment, with {skip_link} resolved once
  # per collection (mint is shared) and {first_name} filled per recipient.
  def recipients_for(collection)
    subscription = collection.subscription
    return [] if subscription.nil?

    segment   = @segments[collection.id]
    body      = resolve_skip_link(@templates.fetch(segment.to_s), collection, segment)
    contacts  = subscription.contacts.can_receive_whatsapp.order(is_primary: :desc, first_name: :asc)

    if contacts.any?
      contacts.map do |contact|
        recipient("c#{contact.id}", contact.first_name, "#{contact.first_name} #{contact.last_name}".strip,
                  contact.formatted_phone, subscription.suburb, segment, body)
      end
    elsif subscription.user&.phone_number.present?
      user = subscription.user
      [recipient("u#{user.id}", user.first_name, user.first_name.to_s,
                 user.phone_number, subscription.suburb, segment, body)]
    else
      []
    end
  end

  def recipient(id, first_name, name, phone, suburb, segment, body)
    {
      id: id, name: name, phone: phone.to_s, suburb: suburb, segment: segment,
      message: body.gsub(NAME_PLACEHOLDER, first_name.to_s)
    }
  end

  # Resolve {skip_link} for this collection. Standard customers get a real skip
  # URL (minting the token on demand); every other segment has the whole line the
  # placeholder sits on removed, so they're never asked. Minting writes, so it
  # only happens for the standard segment when the template uses the token.
  def resolve_skip_link(body, collection, segment)
    return body unless body.include?(SKIP_PLACEHOLDER)

    if segment == :standard
      body.gsub(SKIP_PLACEHOLDER, skip_url(collection.ensure_skip_token!))
    else
      body.lines.reject { |line| line.include?(SKIP_PLACEHOLDER) }.join.strip
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
