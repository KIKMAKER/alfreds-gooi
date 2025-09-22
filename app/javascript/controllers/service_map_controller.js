import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

// data-controller="service-map"
// data-service-map-token-value="..."
// data-service-map-geo-url-value="/assets/suburbs.geojson"
// data-service-map-tuesday-value='["Suburb A", "Suburb B"]' etc.

export default class extends Controller {
  static values = {
    token: String,
    geoUrl: String,
    tuesday: Array,
    wednesday: Array,
    thursday: Array
  }

  connect() {
    if (!this.hasTokenValue || !this.hasGeoUrlValue) return

    mapboxgl.accessToken = this.tokenValue
    this.map = new mapboxgl.Map({
      container: this.element.querySelector("#service-map"),
      style: "mapbox://styles/mapbox/light-v11",
      center: [18.4241, -33.9249], // Cape Town CBD
      zoom: 10.5
    })

    this.map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), "top-right")

    this.map.on("load", async () => {
      const res = await fetch(this.geoUrlValue, { cache: "reload" })
      const geo = await res.json()

      // Assign day per feature by name
      for (const f of geo.features || []) {
        const name = (f.properties?.name || f.properties?.Name || "").trim()
        f.properties = f.properties || {}
        f.properties.day = this.dayFor(name)
      }

      this.map.addSource("service-areas", { type: "geojson", data: geo })

      // Fill polygons, colored by 'day'
      this.map.addLayer({
        id: "areas-fill",
        type: "fill",
        source: "service-areas",
        paint: {
          "fill-color": [
            "match",
            ["get", "day"],
            "Tuesday",   "#5DADE2",
            "Wednesday", "#58D68D",
            "Thursday",  "#F5B041",
            /* default */ "#BDC3C7"
          ],
          "fill-opacity": 0.35
        }
      })

      // Outline
      this.map.addLayer({
        id: "areas-outline",
        type: "line",
        source: "service-areas",
        paint: {
          "line-color": "#333",
          "line-width": 1
        }
      })

      // Click popup
      this.map.on("click", "areas-fill", (e) => {
        const f = e.features && e.features[0]
        if (!f) return
        const name = f.properties?.name || f.properties?.Name || "Area"
        const day = f.properties?.day || "Not currently serviced"
        new mapboxgl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`<strong>${name}</strong><br/>${day}`)
          .addTo(this.map)
      })

      // Cursor pointer
      this.map.on("mouseenter", "areas-fill", () => this.map.getCanvas().style.cursor = "pointer")
      this.map.on("mouseleave", "areas-fill", () => this.map.getCanvas().style.cursor = "")

      this.fitToData(geo)
      this.buildLegend()
      this.enableDayFilters()
    })
  }

  dayFor(name) {
    if (!name) return null
    if (this.tuesdayValue?.includes(name))   return "Tuesday"
    if (this.wednesdayValue?.includes(name)) return "Wednesday"
    if (this.thursdayValue?.includes(name))  return "Thursday"
    return null
  }

  fitToData(geo) {
    const bounds = new mapboxgl.LngLatBounds()
    for (const f of geo.features || []) {
      const c = this._featureBounds(f)
      if (c) bounds.extend(c[0]).extend(c[1])
    }
    if (!bounds.isEmpty()) this.map.fitBounds(bounds, { padding: 40, duration: 0 })
  }

  _featureBounds(f) {
    // quick bbox for Polygon/MultiPolygon
    const coords = (f.geometry?.type === "Polygon")
      ? f.geometry.coordinates.flat(1)
      : (f.geometry?.type === "MultiPolygon" ? f.geometry.coordinates.flat(2) : null)
    if (!coords || coords.length === 0) return null
    let minX =  180, minY =  90, maxX = -180, maxY = -90
    for (const [x, y] of coords) {
      if (x < minX) minX = x; if (x > maxX) maxX = x
      if (y < minY) minY = y; if (y > maxY) maxY = y
    }
    return [[minX, minY], [maxX, maxY]]
  }

  buildLegend() {
    const legend = this.element.querySelector("#service-map-legend")
    if (!legend) return
    legend.innerHTML = `
      <div class="legend-row"><span class="swatch" style="background:#5DADE2"></span> Tuesday</div>
      <div class="legend-row"><span class="swatch" style="background:#58D68D"></span> Wednesday</div>
      <div class="legend-row"><span class="swatch" style="background:#F5B041"></span> Thursday</div>
      <div class="legend-row"><span class="swatch" style="background:#BDC3C7"></span> Not currently serviced</div>
    `
  }

  enableDayFilters() {
    const buttons = this.element.querySelectorAll("[data-day-filter]")
    if (!buttons.length) return
    buttons.forEach(btn => {
      btn.addEventListener("click", () => {
        const val = btn.getAttribute("data-day-filter")
        if (val === "all") {
          this.map.setFilter("areas-fill", null)
          this.map.setFilter("areas-outline", null)
        } else {
          const flt = ["==", ["get", "day"], val]
          this.map.setFilter("areas-fill", flt)
          this.map.setFilter("areas-outline", flt)
        }
      })
    })
  }
}
