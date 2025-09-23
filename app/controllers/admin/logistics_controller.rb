# app/controllers/admin/logistics_controller.rb
class Admin::LogisticsController < ApplicationController
  # before_action :authenticate_user! # keep if you use Devise

  CAPACITY_BUCKETS = 17 # your bakkie capacity

  def index
    # All driver days with a bucket total recorded
    days = DriversDay.where.not(date: nil, total_buckets: nil)

    # Households (stops) that actually happened for each day:
    #   skip: false AND updated_at present
    hh_counts = Collection.where(skip: false).where.not(updated_at: nil)
                          .group(:drivers_day_id).count
    # Build rows
    @rows = days.map do |d|
      hh = hh_counts[d.id].to_i
      b = d.total_buckets.to_i
      ratio = hh.positive? ? (b.to_f / hh) : nil
      {
        id: d.id,
        date: d.date,
        dow: d.date.strftime("%A"),
        buckets: b,
        households: hh,
        bph: ratio,                                    # buckets per household
        cap_used: CAPACITY_BUCKETS.positive? ? (b.to_f / CAPACITY_BUCKETS) : nil,
        kms: d.start_kms && d.end_kms ? (d.end_kms - d.start_kms) : nil,
        hours: (d.start_time && d.end_time) ? ((d.end_time - d.start_time) / 3600.0) : nil
      }
    end

    valid = @rows.select { |r| r[:bph] }

    # Overall + last 3 months
    @overall_bph = avg(valid.map { |r| r[:bph] })
    cutoff = 3.months.ago.to_date
    recent = valid.select { |r| r[:date] && r[:date] >= cutoff }
    @recent_bph  = avg(recent.map { |r| r[:bph] })

    # By day of week (Tue–Thu)
    @by_dow = valid.group_by { |r| r[:dow] }.transform_values do |arr|
      {
        avg_bph:      avg(arr.map { |r| r[:bph] }),
        avg_buckets:  avg(arr.map { |r| r[:buckets] }),
        avg_hh:       avg(arr.map { |r| r[:households] })
      }
    end

    # Recent list (latest 12 days)
    @recent_rows = @rows.sort_by { |r| r[:date] || Date.new(1900) }.last(12).reverse
    @capacity = CAPACITY_BUCKETS
  end

  private

  def avg(arr)
    arr = arr.compact
    return 0.0 if arr.empty?
    (arr.sum.to_f / arr.size).round(2)
  end
end
