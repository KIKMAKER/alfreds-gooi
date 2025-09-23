class Admin::LogisticsController < ApplicationController
  CAPACITY_BUCKETS = 17
  RECENT_LIMIT     = 30

  def index
    days    = DriversDay.where.not(date: nil).where.not(total_buckets: nil)
    day_ids = days.pluck(:id)

    # counts per day
    planned_counts   = Collection.where(drivers_day_id: day_ids).group(:drivers_day_id).count
    completed_counts = Collection.where(drivers_day_id: day_ids, skip: false)
                                 .where.not(updated_at: nil)
                                 .group(:drivers_day_id).count

    @rows = days.map do |d|
      planned   = planned_counts[d.id].to_i
      hh        = completed_counts[d.id].to_i
      buckets   = d.total_buckets.to_i
      skipped   = [planned - hh, 0].max

      bph = hh.positive?      ? (buckets.to_f / hh) : nil           # buckets per household
      hpb = buckets.positive? ? (hh.to_f / buckets) : nil           # households per bucket
      cap = CAPACITY_BUCKETS.positive? ? (buckets.to_f / CAPACITY_BUCKETS) : nil
      rate = planned.positive? ? (skipped.to_f / planned) : nil     # skipped %

      {
        id: d.id,
        date: d.date,
        dow: d.date.strftime("%A"),
        buckets: buckets,
        households: hh,
        planned: planned,
        skipped: skipped,
        skip_rate: rate,
        bph: bph,
        hpb: hpb,
        cap_used: cap,
        kms: (d.start_kms && d.end_kms) ? (d.end_kms - d.start_kms) : nil,
        hours: (d.start_time && d.end_time) ? ((d.end_time - d.start_time) / 3600.0) : nil
      }
    end

    valid_rows     = @rows.select { |r| r[:bph] }
    @overall_bph   = avg(valid_rows.map { |r| r[:bph] })
    @overall_hpb   = avg(valid_rows.map { |r| r[:hpb] })

    cutoff         = 3.months.ago.to_date
    recent_valid   = valid_rows.select { |r| r[:date] && r[:date] >= cutoff }
    @recent_bph    = avg(recent_valid.map { |r| r[:bph] })

    @by_dow = @rows.group_by { |r| r[:dow] }.transform_values do |arr|
      {
        avg_bph:      avg(arr.map { |r| r[:bph] }),
        avg_hpb:      avg(arr.map { |r| r[:hpb] }),
        avg_buckets:  avg(arr.map { |r| r[:buckets] }),
        avg_hh:       avg(arr.map { |r| r[:households] })
      }
    end

    @recent_rows = @rows.sort_by { |r| r[:date] || Date.new(1900) }
                        .last(RECENT_LIMIT).reverse
    @capacity = CAPACITY_BUCKETS
  end

  private

  def avg(arr)
    arr = arr.compact
    return 0.0 if arr.empty?
    (arr.sum.to_f / arr.size).round(2)
  end
end
