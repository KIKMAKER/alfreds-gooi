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

  def customer_map_data
    subscriptions = Subscription
      .active
      .includes(:user, collections: [])
      .where.not(latitude: nil, longitude: nil)

    features = subscriptions.map do |sub|
      # Get last 4 COMPLETED collections (skip pre-created ones with no data)
      recent_collections = sub.collections
        .where.not(updated_at: nil)
        .where(skip: false)
        .order(date: :desc)
        .limit(4)

      if recent_collections.any?
        total_volumes = recent_collections.map do |c|
          # Sum all volume metrics: bags + buckets + buckets_45l + buckets_25l
          (c.bags || 0) + (c.buckets || 0) + (c.buckets_45l || 0) + (c.buckets_25l || 0)
        end
        avg_weekly_volume = (total_volumes.sum.to_f / recent_collections.count).round(2)

        # Separate bags and buckets for display
        avg_bags = (recent_collections.map { |c| c.bags || 0 }.sum / recent_collections.count.to_f).round(2)
        avg_buckets = (recent_collections.map { |c| (c.buckets || 0) + (c.buckets_45l || 0) + (c.buckets_25l || 0) }.sum / recent_collections.count.to_f).round(2)
      else
        avg_weekly_volume = 0
        avg_bags = 0
        avg_buckets = 0
      end

      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [sub.longitude, sub.latitude]
        },
        properties: {
          id: sub.id,
          plan: sub.plan,
          collection_day: sub.collection_day,
          avg_bags_weekly: avg_bags,
          avg_buckets_weekly: avg_buckets,
          avg_total_volume: avg_weekly_volume,
          marker_size: calculate_marker_size(sub, avg_bags, avg_buckets),
          customer_name: sub.user&.first_name || sub.user&.email,
          address: sub.short_address,
          suburb: sub.suburb,
          bucket_size: sub.Commercial? ? sub.bucket_size : nil,
          buckets_per_collection: sub.Commercial? ? sub.buckets_per_collection : nil
        }
      }
    end

    render json: { type: "FeatureCollection", features: features }
  end

  private

  def avg(arr)
    arr = arr.compact
    return 0.0 if arr.empty?
    (arr.sum.to_f / arr.size).round(2)
  end

  def calculate_marker_size(subscription, avg_bags, avg_buckets)
    # Ensure we have valid numbers
    avg_bags = (avg_bags || 0).to_f
    avg_buckets = (avg_buckets || 0).to_f

    if subscription.plan == "Standard"
      normalized = [avg_bags / 6.0, 1.0].min  # 0-6 bags typical
    elsif subscription.plan == "XL"
      normalized = [avg_buckets / 4.0, 1.0].min  # 0-4 buckets typical
    elsif subscription.Commercial?
      # Commercial: higher volumes (10-80 buckets per week possible)
      normalized = [avg_buckets / 20.0, 1.0].min  # 0-20 buckets typical range
    else
      normalized = 0
    end

    # Ensure we always return a valid number
    size = (6 + (normalized * 14)).round(1)
    size.finite? ? size : 6.0  # Fallback to minimum size if NaN/Infinity
  end
end
