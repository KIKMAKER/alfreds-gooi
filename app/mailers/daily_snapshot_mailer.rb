# frozen_string_literal: true
class DailySnapshotMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  # Usage: DailySnapshotMailer.report(drivers_day_id: 123).deliver_now
  def report(drivers_day_id:)
    @drivers_day = DriversDay.find(drivers_day_id)
    @snapshot_url = drivers_day_snapshot_url(@drivers_day)

    mail(
      to: to,
      subject: "Daily Impact Snapshot: #{@drivers_day.date.strftime('%A, %B %d, %Y')}"
    )
  end
end
