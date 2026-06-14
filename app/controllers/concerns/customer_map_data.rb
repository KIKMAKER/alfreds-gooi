module CustomerMapData
  extend ActiveSupport::Concern

  def customer_map_data
    subscriptions = Subscription
      .active
      .includes(:user, collections: [])
      .where.not(latitude: nil, longitude: nil)

    features = subscriptions.map do |sub|
      recent_collections = sub.collections
        .where.not(updated_at: nil)
        .where(skip: false)
        .order(date: :desc)
        .limit(4)

      if recent_collections.any?
        avg_bags    = (recent_collections.sum { |c| c.bags || 0 }.to_f     / recent_collections.count).round(2)
        avg_buckets = (recent_collections.sum { |c| (c.buckets || 0) + (c.buckets_45l || 0) + (c.buckets_25l || 0) }.to_f / recent_collections.count).round(2)
        avg_weekly_volume = (avg_bags + avg_buckets).round(2)
      else
        avg_bags = avg_buckets = avg_weekly_volume = 0
      end

      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [sub.longitude, sub.latitude]
        },
        properties: {
          id:                      sub.id,
          plan:                    sub.plan,
          collection_day:          sub.collection_day,
          avg_bags_weekly:         avg_bags,
          avg_buckets_weekly:      avg_buckets,
          avg_total_volume:        avg_weekly_volume,
          marker_size:             subscription_marker_size(sub, avg_bags, avg_buckets),
          customer_name:           sub.user&.first_name || sub.user&.email,
          address:                 sub.short_address,
          suburb:                  sub.suburb,
          bucket_size:             sub.Commercial? ? sub.bucket_size : nil,
          buckets_per_collection:  sub.Commercial? ? sub.buckets_per_collection : nil
        }
      }
    end

    render json: { type: "FeatureCollection", features: features }
  end

  private

  def subscription_marker_size(subscription, avg_bags, avg_buckets)
    avg_bags    = avg_bags.to_f
    avg_buckets = avg_buckets.to_f

    normalized = case subscription.plan
                 when "Standard"  then [avg_bags    / 6.0,  1.0].min
                 when "XL"        then [avg_buckets / 4.0,  1.0].min
                 when "Commercial" then [avg_buckets / 20.0, 1.0].min
                 else 0
                 end

    size = (6 + (normalized * 14)).round(1)
    size.finite? ? size : 6.0
  end
end
