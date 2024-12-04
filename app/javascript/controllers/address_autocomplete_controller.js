// app/javascript/controllers/address_autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"
import MapboxGeocoder from "@mapbox/mapbox-gl-geocoder"

// Connects to data-controller="address-autocomplete"
export default class extends Controller {
  static values = { apiKey: String }
  static targets = ["address"]

  connect() {
    // console.log("Mapbox Geocoder connected")
    this.geocoder = new MapboxGeocoder({
      accessToken: this.apiKeyValue,
      types: "country,region,place,postcode,locality,neighborhood,address",
      // Set proximity to a central point in Western Cape
      proximity: {
        longitude: 18.4239, // Longitude of Cape Town
        latitude: -33.9189  // Latitude of Cape Town
      },
      // Set bbox to the bounding box of Western Cape
      bbox: [
        17.8333, // Minimum longitude
        -34.8333, // Minimum latitude
        21.2087, // Maximum longitude
        -31.2930  // Maximum latitude
      ],
      countries: "ZA",
    })
    this.geocoder.addTo(this.element)
    this.geocoder.on("result", event => this.setInputValue(event))
    this.geocoder.on("clear", () => this.clearInputValue())
  }

  setInputValue(event) {
    this.addressTarget.value = event.result["place_name"]
  }

  clearInputValue() {
    this.addressTarget.value = ""
  }

  disconnect() {
    this.geocoder.onRemove()
  }
}
