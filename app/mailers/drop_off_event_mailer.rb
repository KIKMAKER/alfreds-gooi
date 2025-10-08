class DropOffEventMailer < ApplicationMailer
  def completion_notification(drop_off_event)
    @drop_off_event = drop_off_event
    @drop_off_site = drop_off_event.drop_off_site
    @user = @drop_off_site.user

    # Get this week's events for stats
    week_start = drop_off_event.date.beginning_of_week
    week_end = drop_off_event.date.end_of_week
    @week_events = @drop_off_site.drop_off_events
                                  .where(date: week_start..week_end, is_done: true)

    @weekly_buckets = @week_events.sum { |e| e.buckets.count }
    @weekly_weight = @week_events.sum { |e| e.total_weight_from_buckets }

    mail(
      to: @user.email,
      subject: "Drop-off completed at #{@drop_off_site.name} - #{drop_off_event.date.strftime('%A, %B %e')}"
    )
  end
end
