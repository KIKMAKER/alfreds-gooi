# frozen_string_literal: true
class WeeklyStatsMailer < ApplicationMailer
  default from: "howzit@gooi.me"

  # Usage: WeeklyStatsMailer.report(start_date:, end_date:).deliver_now
  # Or pass anchor_date + mode: :route_week to compute Tue–Thu
  def report(to: nil, start_date: nil, end_date: nil, anchor_date: nil, mode: :default)
    @stats = WeeklyStats.call(start_date: start_date, end_date: end_date, anchor_date: anchor_date, mode: mode)
    recipients = (["howzit@gooi.me"] + User.admin.pluck(:email)).uniq
    mail(to: recipients, subject: "Gooi Weekly Stats: #{@stats.period_label}")
  end
end
