class GeographicRouteOptimiser
  BUSINESS_LOCATION = { lat: -33.9497, lng: 18.4735 } # 27 Hare Street, Mowbray

  def initialize(drivers_day)
    @drivers_day = drivers_day
    @collections = drivers_day.collections.includes(subscription: :user).where(skip: false).to_a
  end

  def optimize!
    return { success: false, error: 'No collections to optimize' } if @collections.empty?

    Rails.logger.info "🗺️ Starting geographic route optimization for #{@collections.count} collections"

    # Filter collections with valid coordinates
    collections_with_coords = @collections.select do |c|
      c.subscription.latitude.present? && c.subscription.longitude.present?
    end

    if collections_with_coords.empty?
      return { success: false, error: 'No collections have valid coordinates' }
    end

    if collections_with_coords.length != @collections.length
      Rails.logger.warn "⚠️ #{@collections.length - collections_with_coords.length} collections missing coordinates"
    end

    # Optimize using nearest neighbor algorithm starting from business
    optimized_collections = nearest_neighbor_sort(collections_with_coords)

    # Update positions
    update_positions(optimized_collections)

    {
      success: true,
      total_optimized: optimized_collections.count,
      route_url: generate_google_maps_url(optimized_collections)
    }
  rescue StandardError => e
    Rails.logger.error "❌ Geographic optimization failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  def nearest_neighbor_sort(collections)
    optimized = []
    remaining = collections.dup

    # Start from business location
    current_lat = BUSINESS_LOCATION[:lat]
    current_lng = BUSINESS_LOCATION[:lng]

    Rails.logger.info "📍 Starting route from business: #{BUSINESS_LOCATION[:lat]}, #{BUSINESS_LOCATION[:lng]}"

    while remaining.any?
      # Find nearest collection to current position
      nearest = remaining.min_by do |collection|
        distance_between(
          current_lat, current_lng,
          collection.subscription.latitude, collection.subscription.longitude
        )
      end

      distance = distance_between(
        current_lat, current_lng,
        nearest.subscription.latitude, nearest.subscription.longitude
      )

      optimized << nearest
      remaining.delete(nearest)

      Rails.logger.debug "  → #{nearest.subscription.user.first_name} at #{nearest.subscription.street_address} (#{(distance * 1000).round}m)"

      current_lat = nearest.subscription.latitude
      current_lng = nearest.subscription.longitude
    end

    # Log final return distance
    final_distance = distance_between(
      current_lat, current_lng,
      BUSINESS_LOCATION[:lat], BUSINESS_LOCATION[:lng]
    )
    Rails.logger.info "📍 Returning to business (#{(final_distance * 1000).round}m)"

    Rails.logger.info "✅ Optimized #{optimized.count} collections geographically"
    optimized
  end

  # Calculate distance between two points using Haversine formula
  def distance_between(lat1, lng1, lat2, lng2)
    rad_per_deg = Math::PI / 180
    rlat1 = lat1 * rad_per_deg
    rlat2 = lat2 * rad_per_deg
    rlng1 = lng1 * rad_per_deg
    rlng2 = lng2 * rad_per_deg

    dlon = rlng2 - rlng1
    dlat = rlat2 - rlat1

    a = Math.sin(dlat / 2)**2 + Math.cos(rlat1) * Math.cos(rlat2) * Math.sin(dlon / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    6371 * c # Distance in kilometers
  end

  def update_positions(optimized_collections)
    ActiveRecord::Base.transaction do
      optimized_collections.each_with_index do |collection, index|
        new_position = index + 1

        collection.update_column(:position, new_position)

        # Sync to subscription.collection_order
        if collection.subscription.present?
          collection.subscription.update_column(:collection_order, new_position)
        end
      end
    end
  end

  def generate_google_maps_url(optimized_collections)
    waypoints = [BUSINESS_LOCATION]

    optimized_collections.each do |collection|
      waypoints << {
        lat: collection.subscription.latitude,
        lng: collection.subscription.longitude
      }
    end

    waypoints << BUSINESS_LOCATION # Return to business

    # Build Google Maps URL
    waypoint_strings = waypoints.compact.map { |wp| "#{wp[:lat]},#{wp[:lng]}" }
    "https://www.google.com/maps/dir/#{waypoint_strings.join('/')}"
  end
end
