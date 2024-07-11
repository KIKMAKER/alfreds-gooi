require 'net/http'
require 'uri'
require 'json'

class RouteOptimizer
  GOOGLE_MAPS_API_KEY = ENV['GOOGLE_MAPS_API_KEY']

  def self.optimize_route
    collections = Collection.where(skip: false, date: Date.today)


    return if collections.empty?

    # Collect all the addresses for collections
    waypoints = collections.map { |c| c.collection_address }

    # Add the business address as the first and last address
    waypoints.unshift(BUSINESS_ADDRESS)
    waypoints.push(BUSINESS_ADDRESS)

    uri = URI.parse("https://maps.googleapis.com/maps/api/directions/json?origin=#{waypoints.first}&destination=#{waypoints.last}&waypoints=optimize:true|#{waypoints[1...-1].join('|')}&key=#{GOOGLE_MAPS_API_KEY}")

    response = Net::HTTP.get_response(uri)
    parsed_response = JSON.parse(response.body)

    if parsed_response['status'] == 'OK'
      route_order = parsed_response['routes'].first['waypoint_order']
      route_order.each_with_index do |collection_index, order|
        collections[collection_index].update(order: order + 1)
      end
    else
      Rails.logger.error("Google Maps API error: #{parsed_response['status']}")
    end
  end
end
