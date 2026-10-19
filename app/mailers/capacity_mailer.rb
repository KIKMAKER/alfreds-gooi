class CapacityMailer < ApplicationMailer
  def exceeded(drop_off_event, reasons)
    @event = drop_off_event
    @site = drop_off_event.drop_off_site
    @reasons = reasons

    mail(
      to: ENV["CAPACITY_NOTIFY_TO"] || "howzit@gooi.me",
      subject: "Over capacity at #{@site.name} on #{@event.date.strftime('%-d %b')}"
    )
  end
end
