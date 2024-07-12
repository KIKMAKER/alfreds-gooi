// app/javascript/controllers/address_autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"
import MapboxGeocoder from "https://unpkg.com/@mapbox/mapbox-gl-geocoder@5.0.0/dist/mapbox-gl-geocoder.min.js"


// Connects to data-controller="address-autocomplete"
export default class extends Controller {
  static values = { apiKey: String }
  static targets = ["address"]

  connect() {
    this.geocoder = new MapboxGeocoder({
      accessToken: this.apiKeyValue,
      types: "country,region,place,postcode,locality,neighborhood,address"
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
