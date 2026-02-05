class Ahoy::Store < Ahoy::DatabaseStore
end

# Enable JavaScript API for custom event tracking
Ahoy.api = true

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true
