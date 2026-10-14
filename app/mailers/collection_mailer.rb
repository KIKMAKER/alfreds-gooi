class CollectionMailer < ApplicationMailer
  # Set your email via ENV or fall back to first admin / a default
  default to: -> {
    ENV["SKIP_ALERT_TO"] ||
      "howzit@gooi.me" ||
      "gooicapetown@gmail.com"
  }

  def skipped(collection_id:, actor_id: nil, reason: "unspecified", occurred_at: Time.zone.now)
    @collection   = Collection.find(collection_id)
    @subscription = @collection.subscription
    @customer     = @subscription&.user
    @actor        = actor_id && User.find_by(id: actor_id)
    @reason       = reason
    @occurred_at  = occurred_at
    mail(subject: "[Skip] ##{@collection.id} · #{@customer&.first_name} · #{@collection.date}")
  end

  def note_added(collection_id:)
    @collection   = Collection.find(collection_id)
    @subscription = @collection.subscription
    mail(to: Collection::MY_NOTE_ALERT_EMAIL, subject: "Alfred left a note on your collection (#{@collection.date.strftime('%d %b')})")
  end
end
