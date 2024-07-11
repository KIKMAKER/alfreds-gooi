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

    waypoints = collections.map { |c| c.subscription.street_address }

    Rails.logger.debug("Addresses being sent to Google Maps API: #{waypoints}")

    waypoints.unshift(BUSINESS_ADDRESS)
    waypoints.push(BUSINESS_ADDRESS)

    total_waypoints = waypoints.length - 2 # Exclude the origin and destination

    batches = total_waypoints.fdiv(MAX_WAYPOINTS).ceil

    route_order = []
    collections_with_index = collections.to_a.each_with_index.to_a

    batches.times do |batch_index|
      start_index = batch_index * MAX_WAYPOINTS
      end_index = [start_index + MAX_WAYPOINTS - 1, total_waypoints - 1].min

      current_batch = waypoints[start_index + 1..end_index + 1]
      current_batch.unshift(BUSINESS_ADDRESS)
      current_batch.push(BUSINESS_ADDRESS)

      encoded_waypoints = current_batch.map { |address| ERB::Util.url_encode(address) }
      uri = URI.parse("https://maps.googleapis.com/maps/api/directions/json?origin=#{encoded_waypoints.first}&destination=#{encoded_waypoints.last}&waypoints=optimize:true|#{encoded_waypoints[1...-1].join('|')}&key=#{GOOGLE_MAPS_API_KEY}")

      Rails.logger.debug("Request URI: #{uri}")
      response = Net::HTTP.get_response(uri)
      parsed_response = JSON.parse(response.body)

      if parsed_response['status'] == 'OK'
        batch_route_order = parsed_response['routes'].first['waypoint_order']

        batch_route_order.each_with_index do |batch_collection_index, order|
          global_collection_index = start_index + batch_collection_index
          collection, original_index = collections_with_index[global_collection_index]
          collection.update!(order: original_index + 1)
          route_order << collection
          puts "Collection for #{collection.subscription.user.first_name} at #{collection.subscription.street_address} set to order #{original_index + 1}"
        end
      else
        Rails.logger.error("Google Maps API error: #{parsed_response['status']}")
        Rails.logger.error("Response: #{parsed_response}")
        Rails.logger.error("Problematic addresses: #{current_batch}")
      end
    end
  end
end
