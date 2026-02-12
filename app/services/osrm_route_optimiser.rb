require 'net/http'
require 'uri'
require 'json'

class OsrmRouteOptimiser
  OSRM_SERVER = 'http://router.project-osrm.org'
  BUSINESS_LOCATION = { lat: -33.9497, lng: 18.4735 } # 27 Hare Street, Mowbray

  def initialize(drivers_day)
    @drivers_day = drivers_day
    @collections = drivers_day.collections.includes(subscription: :user).where(skip: false).to_a
    @drop_offs = drivers_day.drop_off_events.order(:position).to_a
  end

  def optimize!
    return { success: false, error: 'No collections to optimize' } if @collections.empty?

    Rails.logger.info "🚗 Starting OSRM route optimization for #{@collections.count} collections and #{@drop_offs.count} drop-offs"

    # Split collections into segments based on drop-off positions
    segments = split_into_segments

    # Optimize each segment
    optimized_route = []
    segments.each_with_index do |segment, index|
      if segment[:type] == :drop_off
        # Drop-offs keep their position
        optimized_route << segment
      else
        # Optimize collection segment
        optimized_segment = optimize_segment(segment, index == 0, index == segments.length - 1)
        optimized_route.concat(optimized_segment) if optimized_segment
      end
    end

    # Update positions for all route items
    update_positions(optimized_route)

    {
      success: true,
      total_optimized: @collections.count,
      segments: segments.count,
      route_url: generate_google_maps_url(optimized_route)
    }
  rescue StandardError => e
    Rails.logger.error "❌ OSRM optimization failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  def split_into_segments
    # If no drop-offs, return all collections as one segment
    return [{ type: :collections, items: @collections, start_position: 1 }] if @drop_offs.empty?

    segments = []
    current_segment_collections = []
    current_position = 1

    # Combine all route items and sort by position
    all_items = (@collections + @drop_offs).sort_by(&:position)

    all_items.each do |item|
      if item.is_a?(DropOffEvent)
        # End current collection segment if it has items
        if current_segment_collections.any?
          segments << {
            type: :collections,
            items: current_segment_collections,
            start_position: current_position
          }
          current_position += current_segment_collections.length
          current_segment_collections = []
        end

        # Add drop-off segment
        segments << {
          type: :drop_off,
          item: item,
          position: current_position
        }
        current_position += 1
      else
        # Add collection to current segment
        current_segment_collections << item
      end
    end

    # Add final segment if it has collections
    if current_segment_collections.any?
      segments << {
        type: :collections,
        items: current_segment_collections,
        start_position: current_position
      }
    end

    segments
  end

  def optimize_segment(segment, is_first_segment, is_last_segment)
    collections = segment[:items]
    return collections if collections.length <= 1 # No optimization needed

    # Build coordinates string for OSRM
    coordinates = collections.map do |collection|
      sub = collection.subscription
      next unless sub.latitude && sub.longitude
      "#{sub.longitude},#{sub.latitude}" # OSRM uses lng,lat format
    end.compact

    # Skip if any collections don't have coordinates
    if coordinates.length != collections.length
      Rails.logger.warn "⚠️ Some collections missing coordinates, skipping optimization for this segment"
      return collections
    end

    # Add business location at start and end if needed
    coordinates.unshift("#{BUSINESS_LOCATION[:lng]},#{BUSINESS_LOCATION[:lat]}") if is_first_segment
    coordinates.push("#{BUSINESS_LOCATION[:lng]},#{BUSINESS_LOCATION[:lat]}") if is_last_segment

    coordinates_string = coordinates.join(';')

    # Build OSRM Trip API URL
    # Trip service solves the Traveling Salesman Problem
    uri = URI.parse("#{OSRM_SERVER}/trip/v1/driving/#{coordinates_string}")
    params = {
      source: is_first_segment ? 'first' : 'any',
      destination: is_last_segment ? 'last' : 'any',
      roundtrip: is_first_segment && is_last_segment ? 'true' : 'false'
    }
    uri.query = URI.encode_www_form(params)

    Rails.logger.debug "📍 OSRM Request: #{uri}"

    # Make request to OSRM
    response = Net::HTTP.get_response(uri)
    parsed_response = JSON.parse(response.body)

    if parsed_response['code'] == 'Ok'
      # OSRM returns waypoints in optimized order
      waypoint_indices = parsed_response['waypoints'].map { |wp| wp['waypoint_index'] }

      # Remove business location indices if added
      waypoint_indices.shift if is_first_segment # Remove start
      waypoint_indices.pop if is_last_segment   # Remove end

      # Map back to collections
      optimized_collections = waypoint_indices.map { |i| collections[i] }

      Rails.logger.info "✅ Optimized segment: #{waypoint_indices.inspect}"
      optimized_collections
    else
      Rails.logger.error "❌ OSRM error: #{parsed_response['code']} - #{parsed_response['message']}"
      collections # Return original order on error
    end
  end

  def update_positions(optimized_route)
    ActiveRecord::Base.transaction do
      optimized_route.each_with_index do |item, index|
        new_position = index + 1

        if item.is_a?(Hash) && item[:type] == :drop_off
          # Drop-off
          drop_off = item[:item]
          drop_off.update_column(:position, new_position)
          Rails.logger.debug "📍 Drop-off #{drop_off.drop_off_site.name} → position #{new_position}"
        else
          # Collection
          item.update_column(:position, new_position)

          # Sync to subscription.collection_order
          if item.subscription.present?
            item.subscription.update_column(:collection_order, new_position)
          end

          Rails.logger.debug "📍 #{item.subscription.user.first_name} at #{item.subscription.street_address} → position #{new_position}"
        end
      end
    end
  end

  def generate_google_maps_url(optimized_route)
    waypoints = [BUSINESS_LOCATION]

    optimized_route.each do |item|
      if item.is_a?(Hash) && item[:type] == :drop_off
        drop_off = item[:item]
        waypoints << { lat: drop_off.drop_off_site.latitude, lng: drop_off.drop_off_site.longitude }
      else
        waypoints << { lat: item.subscription.latitude, lng: item.subscription.longitude }
      end
    end

    waypoints << BUSINESS_LOCATION # Return to business

    # Build Google Maps URL
    waypoint_strings = waypoints.compact.map { |wp| "#{wp[:lat]},#{wp[:lng]}" }
    "https://www.google.com/maps/dir/#{waypoint_strings.join('/')}"
  end
end
