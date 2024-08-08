require 'net/http'
require 'uri'
require 'json'

class RouteOptimiser
  GOOGLE_MAPS_API_KEY = ENV['GOOGLE_MAPS_API_KEY']
  BUSINESS_ADDRESS = '27 Hare Street, Mowbray, Cape Town, South Africa'
  MAX_WAYPOINTS = 25

  def self.optimise_route
    collections = Collection.includes(:subscription).where(created_at: Date.today.all_day, date: Date.today , skip: false)
    return if collections.empty?

    # Sort collections by suburb and street address
    sorted_collections = collections.sort_by { |c| [c.subscription.suburb] }

    waypoints = sorted_collections.map { |c| c.subscription.street_address }

    Rails.logger.debug("Addresses being sent to Google Maps API: #{waypoints}")

    total_waypoints = waypoints.length

    if total_waypoints <= MAX_WAYPOINTS
      # Optimize in one go if within the limit
      process_batch(waypoints, sorted_collections, true, true)
    else
      # Process in smaller batches
      batches = total_waypoints.fdiv(MAX_WAYPOINTS).ceil
      optimized_batches = []

      batches.times do |batch_index|
        start_index = batch_index * MAX_WAYPOINTS
        end_index = [start_index + MAX_WAYPOINTS - 1, total_waypoints - 1].min

        current_batch = waypoints[start_index..end_index]

        if batch_index == 0
          current_batch.unshift(BUSINESS_ADDRESS)
        end

        if batch_index == batches - 1
          current_batch.push(BUSINESS_ADDRESS)
        end

        optimized_batches.concat(process_batch(current_batch, sorted_collections[start_index..end_index], batch_index == 0, batch_index == batches - 1))
      end

      update_collections(optimized_batches)
      display_route(optimized_batches)
    end
  end

  def self.process_batch(waypoints, collections, include_start, include_end)
    encoded_waypoints = waypoints.map { |address| ERB::Util.url_encode(address) }
    origin = include_start ? encoded_waypoints.shift : BUSINESS_ADDRESS
    destination = include_end ? encoded_waypoints.pop : BUSINESS_ADDRESS
    waypoints_str = encoded_waypoints.join('|')

    uri = URI.parse("https://maps.googleapis.com/maps/api/directions/json?origin=#{origin}&destination=#{destination}&waypoints=optimize:true|#{waypoints_str}&key=#{GOOGLE_MAPS_API_KEY}")

    Rails.logger.debug("Request URI: #{uri}")
    response = Net::HTTP.get_response(uri)
    parsed_response = JSON.parse(response.body)

    if parsed_response['status'] == 'OK'
      batch_route_order = parsed_response['routes'].first['waypoint_order']

      # Map the optimized order to the original collections
      batch_route_order.map do |batch_collection_index|
        collections[batch_collection_index]
      end
    else
      Rails.logger.error("Google Maps API error: #{parsed_response['status']}")
      Rails.logger.error("Response: #{parsed_response}")
      Rails.logger.error("Problematic addresses: #{waypoints}")
      []
    end
  end

  def self.update_collections(optimized_collections)
    optimized_collections.each_with_index do |collection, order|
      collection.update!(order: order + 1)
      puts "Collection for #{collection.subscription.user.first_name} at #{collection.subscription.street_address} set to order #{order + 1}"
    end
  end

  def self.display_route(optimized_collections)
    waypoints = optimized_collections.map { |c| c.subscription.street_address }
    waypoints.unshift(BUSINESS_ADDRESS)
    waypoints.push(BUSINESS_ADDRESS)

    encoded_waypoints = waypoints.map { |address| ERB::Util.url_encode(address) }
    waypoints_str = encoded_waypoints.join('/')

    maps_url = "https://www.google.com/maps/dir/#{waypoints_str}"
    puts "View the optimized route here: #{maps_url}"
  end
end
