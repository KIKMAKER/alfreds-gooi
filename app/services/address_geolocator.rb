require 'net/http'
require 'uri'
require 'json'

class RouteOptimiser
  GOOGLE_MAPS_API_KEY = ENV['GOOGLE_MAPS_API_KEY']
  BUSINESS_ADDRESS = '27 Hare Street, Mowbray, Cape Town, South Africa'
  MAX_WAYPOINTS = 25

  def self.optimise_route
    collections = Collection.includes(subscription: :user).where(skip: false, date: Date.today + 6)
    return if collections.empty?

    # Sort collections by suburb and street address
    sorted_collections = collections.sort_by { |c| [c.subscription.suburb, c.subscription.street_address] }

    waypoints = sorted_collections.map { |c| c.subscription.street_address }

    Rails.logger.debug("Addresses being sent to Google Maps API: #{waypoints}")

    # Add the business address as the first and last address
    waypoints.unshift(BUSINESS_ADDRESS)
    waypoints.push(BUSINESS_ADDRESS)

    total_waypoints = waypoints.length - 2 # Exclude the origin and destination

    if total_waypoints <= MAX_WAYPOINTS
      # Optimize in one go if within the limit
      process_batch(waypoints, sorted_collections)
    else
      # Process in smaller batches
      batches = total_waypoints.fdiv(MAX_WAYPOINTS).ceil
      optimized_batches = []

      batches.times do |batch_index|
        start_index = batch_index * MAX_WAYPOINTS
        end_index = [start_index + MAX_WAYPOINTS - 1, total_waypoints - 1].min

        current_batch = waypoints[start_index + 1..end_index + 1]
        current_batch.unshift(BUSINESS_ADDRESS)
        current_batch.push(BUSINESS_ADDRESS)

        optimized_batches.concat(process_batch(current_batch, sorted_collections[start_index..end_index]))
      end

      update_collections(optimized_batches)
    end
  end

  def self.process_batch(waypoints, collections)
    encoded_waypoints = waypoints.map { |address| ERB::Util.url_encode(address) }
    uri = URI.parse("https://maps.googleapis.com/maps/api/directions/json?origin=#{encoded_waypoints.first}&destination=#{encoded_waypoints.last}&waypoints=optimize:true|#{encoded_waypoints[1...-1].join('|')}&key=#{GOOGLE_MAPS_API_KEY}")

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
end
