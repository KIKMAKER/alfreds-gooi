# frozen_string_literal: true
class WeeklyStatsMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  # Usage: WeeklyStatsMailer.report(start_date:, end_date:).deliver_now
  # Or pass anchor_date + mode: :route_week to compute Tue–Thu
  # Pass drivers_day_id to include a link to the rendered Instagram snapshot template
  def report(to: nil, start_date: nil, end_date: nil, anchor_date: nil, mode: :default, drivers_day_id: nil)
    @stats = WeeklyStats.call(start_date: start_date, end_date: end_date, anchor_date: anchor_date, mode: mode)
    @snapshot_url = weekly_snapshot_drivers_day_url(drivers_day_id) if drivers_day_id
    recipients = (["howzit@gooi.me"] + User.admin.pluck(:email)).uniq
    mail(to: recipients, subject: "Gooi Weekly Stats: #{@stats.period_label}")
  end
end
