require 'net/http'
require 'uri'
require 'json'

class RouteXlOptimiser
  ROUTEXL_API_URL = 'https://api.routexl.com/tour'
  BUSINESS_ADDRESS = '27 Hare Street, Mowbray, Cape Town, South Africa'
  # Business coordinates (geocoded from address)
  BUSINESS_LAT = -33.9405
  BUSINESS_LNG = 18.4709
  ROUTEXL_USERNAME = ENV['ROUTEXL_USERNAME']
  ROUTEXL_PASSWORD = ENV['ROUTEXL_PASSWORD']

  def self.optimise_route(collection_day)
    raise ArgumentError, "collection_day is required" if collection_day.blank?
    raise "ROUTEXL_USERNAME environment variable not set" if ROUTEXL_USERNAME.blank?
    raise "ROUTEXL_PASSWORD environment variable not set" if ROUTEXL_PASSWORD.blank?

    # Get all active subscriptions for this day with coordinates
    subscriptions = Subscription.active
                                .where(collection_day: collection_day)
                                .where.not(latitude: nil, longitude: nil)
                                .includes(:user)
                                .to_a

    return { success: false, message: "No active subscriptions with coordinates found for #{collection_day}" } if subscriptions.empty?

    Rails.logger.info("RouteXL: Optimizing #{subscriptions.count} subscriptions for #{collection_day}")

    # Build locations payload for RouteXL API
    locations = build_locations_payload(subscriptions, collection_day)

    # Make API request
    response = call_routexl_api(locations)

    if response[:success]
      # Update subscription collection_order based on optimized route
      update_subscription_order(subscriptions, response[:route])
      {
        success: true,
        message: "Successfully optimized #{subscriptions.count} #{collection_day} subscriptions",
        count: subscriptions.count,
        distance: response[:distance],
        time: response[:time]
      }
    else
      {
        success: false,
        message: "RouteXL API error: #{response[:error]}"
      }
    end
  rescue StandardError => e
    Rails.logger.error("RouteXL optimization error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { success: false, message: "Error: #{e.message}" }
  end

  private

  def self.build_locations_payload(subscriptions, collection_day)
    locations = []

    # Add business address as departure point (index 0)
    locations << {
      name: 'Depot (Start)',
      lat: BUSINESS_LAT,
      lng: BUSINESS_LNG
    }

    # Add each subscription as a location
    subscriptions.each do |sub|
      locations << {
        name: "#{sub.user.first_name} #{sub.user.last_name}".strip,
        lat: sub.latitude,
        lng: sub.longitude
      }
    end

    # Add drop-off site for this collection day (before final depot)
    drop_off_site = DropOffSite.find_by(collection_day: collection_day)
    if drop_off_site && drop_off_site.latitude.present? && drop_off_site.longitude.present?
      locations << {
        name: "#{drop_off_site.name} (Drop-off)",
        lat: drop_off_site.latitude,
        lng: drop_off_site.longitude
      }
      Rails.logger.info("RouteXL: Added drop-off site '#{drop_off_site.name}' to route")
    else
      Rails.logger.warn("RouteXL: No drop-off site found for #{collection_day}")
    end

    # Add business address as arrival point (last index)
    locations << {
      name: 'Depot (End)',
      lat: BUSINESS_LAT,
      lng: BUSINESS_LNG
    }

    locations
  end

  def self.call_routexl_api(locations)
    uri = URI.parse(ROUTEXL_API_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    # Set Basic Authentication
    request.basic_auth(ROUTEXL_USERNAME, ROUTEXL_PASSWORD)

    # RouteXL expects form-encoded data with locations as JSON string
    form_data = URI.encode_www_form({
      'locations' => locations.to_json
    })

    request.body = form_data

    Rails.logger.debug("RouteXL Request: #{uri}")
    Rails.logger.debug("RouteXL Locations: #{locations.to_json}")

    response = http.request(request)

    Rails.logger.debug("RouteXL Response Code: #{response.code}")
    Rails.logger.debug("RouteXL Response Body: #{response.body}")

    parsed_response = JSON.parse(response.body)

    if response.code.to_i == 200 && parsed_response['route']
      {
        success: true,
        route: parsed_response['route'],
        distance: parsed_response['distance'],
        time: parsed_response['time']
      }
    else
      error_message = parsed_response['error'] || parsed_response['message'] || 'Unknown error'
      Rails.logger.error("RouteXL API error: #{error_message}")
      Rails.logger.error("Response code: #{response.code}")
      Rails.logger.error("Response body: #{response.body}")
      {
        success: false,
        error: error_message
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error("RouteXL JSON parse error: #{e.message}")
    Rails.logger.error("Response body: #{response&.body}")
    { success: false, error: "Invalid JSON response from RouteXL: #{e.message}" }
  rescue StandardError => e
    Rails.logger.error("RouteXL request error: #{e.message}")
    { success: false, error: e.message }
  end

  def self.update_subscription_order(subscriptions, route_object)
    # Route object keys are the ORDER in optimized route (0=start, 1=first stop, etc)
    # Route object values contain the waypoint info including NAME
    # We need to match by name to find which subscription each position refers to

    Rails.logger.info("RouteXL optimized route (first 5): #{route_object.to_a.first(5).to_h.inspect}")

    # Create a lookup hash: normalized name => subscription
    subscription_lookup = {}
    subscriptions.each do |sub|
      name = "#{sub.user.first_name} #{sub.user.last_name}".strip
      subscription_lookup[name] = sub
    end

    # Sort route by keys to get order, skip first (0=depot) and last (end depot)
    sorted_route = route_object.sort_by { |key, _| key.to_i }
    optimized_stops = sorted_route[1..-2]  # Remove first and last (depots)

    Rails.logger.info("Processing #{optimized_stops.count} stops...")

    optimized_stops.each_with_index do |(route_position, waypoint_data), index|
      customer_name = waypoint_data["name"]
      subscription = subscription_lookup[customer_name]

      if subscription
        new_order = index + 1
        subscription.update!(collection_order: new_order)
        Rails.logger.debug("Position #{new_order}: #{customer_name} (route pos #{route_position})")
      else
        Rails.logger.warn("Could not find subscription for: #{customer_name}")
      end
    end
  end
end
