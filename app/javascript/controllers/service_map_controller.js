import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

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

    // Precompute normalized sets for fast lookup
    this.tuesdaySet   = new Set((this.tuesdayValue || []).map(n => this.standardize(n)))
    this.wednesdaySet = new Set((this.wednesdayValue || []).map(n => this.standardize(n)))
    this.thursdaySet  = new Set((this.thursdayValue  || []).map(n => this.standardize(n)))

    mapboxgl.accessToken = this.tokenValue

    // ——— Camera defaults (Constantia-ish) ———
    const CONSTANTIA = [18.36, -34.00]

    this.map = new mapboxgl.Map({
      container: this.element.querySelector("#service-map"),
      style: "mapbox://styles/mapbox/light-v11",
      center: CONSTANTIA,
      zoom: 20.9,
      maxBounds: [[17.8, -34.5], [19.0, -33.4]],
      minZoom: 9,
      maxZoom: 100,
      dragRotate: false,
      touchZoomRotate: { rotate: false }
    })
    this.map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), "top-right")

    this.map.on("load", async () => {
      const res = await fetch(this.geoUrlValue, { cache: "reload" })
      const geo = await res.json()

      // Tag each feature with day (do this once)
      for (const f of (geo.features || [])) {
        const label = this.nameFromProps(f.properties)
        f.properties = f.properties || {}
        f.properties._label = label
        f.properties.day = this.dayFor(label)
      }

      // Only the areas you service
      const serviced = {
        type: "FeatureCollection",
        features: geo.features.filter(f => !!f.properties?.day)
      }

      this.map.addSource("service-areas", { type: "geojson", data: geo })

      // Fills
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

      // Outlines
      this.map.addLayer({
        id: "areas-outline",
        type: "line",
        source: "service-areas",
        paint: { "line-color": "#333", "line-width": 1 }
      })

      // Click popup
      this.map.on("click", "areas-fill", (e) => {
        const f = e.features?.[0]
        if (!f) return
        const name = f.properties?._label || this.nameFromProps(f.properties) || "Area"
        const day  = f.properties?.day || "Not yet serviced"
        new mapboxgl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`<strong>${name}</strong><br/>${day}`)
          .addTo(this.map)
      })
      this.map.on("mouseenter", "areas-fill", () => this.map.getCanvas().style.cursor = "pointer")
      this.map.on("mouseleave", "areas-fill", () => this.map.getCanvas().style.cursor = "")

      // —— Choose ONE of these framings ——

      // A) Fit to serviced data, biased west (recommended)
      this.fitToData(serviced, {
        padding: { top: 40, right: 24, bottom: 40, left: 160 },
        maxZoom: 11.4
      })

      // B) Or fit to a fixed Atlantic-seaboard rectangle (comment A out if you use this)
      // const ATLANTIC_VIEW_BOUNDS = [[18.28, -34.18], [18.66, -33.87]]
      // this.map.fitBounds(ATLANTIC_VIEW_BOUNDS, { padding: 40, maxZoom: 12, duration: 0 })

      this.buildLegend()
      this.enableDayFilters()
    })
  }

  // ---------- name helpers ----------
  nameFromProps(props) {
    if (!props) return ""
    const keys = ["OFC_SBRB_NAME","OS Name","OS_NAME","NAME","Name","name"]
    for (const k of keys) if (props[k]) return String(props[k]).trim()
    return ""
  }
  normalize(n) {
    return (n || "")
      .toUpperCase()
      .replace(/[’']/g, "")
      .replace(/\s*\(.*?\)\s*/g, " ")
      .replace(/\bUPPER\s+|\bLOWER\s+/g, "")
      .replace(/[\/\-_]/g, " ")
      .replace(/\s+/g, "")
      .trim()
  }
  alias(norm) {
    const A = {
      "SCHOTSCHEKLOOF": "BOKAAP",
      "DEWATERKANT": "GREENPOINT",
      "MARINADAGAMA": "MUIZENBERG",
      "HARFIELDVILLAGE": "CLAREMONT",
      "WITTEBOOMEN": "CONSTANTIA",
      "DEVILSPEAKESTATE": "VREDEHOEK"
    }
    return A[norm] || norm
  }
  standardize(n) { return this.alias(this.normalize(n)) }

  dayFor(name) {
    const key = this.standardize(name)
    if (this.tuesdaySet.has(key))   return "Tuesday"
    if (this.wednesdaySet.has(key)) return "Wednesday"
    if (this.thursdaySet.has(key))  return "Thursday"
    return null
  }

  // ---------- view helpers ----------
  fitToData(geo, opts = {}) {
    const bounds = new mapboxgl.LngLatBounds()
    for (const f of (geo.features || [])) {
      const b = this._featureBounds(f)
      if (b) bounds.extend(b[0]).extend(b[1])
    }
    if (!bounds.isEmpty()) {
      this.map.fitBounds(bounds, {
        padding: opts.padding ?? 40,
        maxZoom: opts.maxZoom ?? 12,
        duration: 0
      })
    }
  }

  _featureBounds(f) {
    const coords = (f.geometry?.type === "Polygon")
      ? f.geometry.coordinates.flat(1)
      : (f.geometry?.type === "MultiPolygon" ? f.geometry.coordinates.flat(2) : null)
    if (!coords || !coords.length) return null
    let minX = 180, minY = 90, maxX = -180, maxY = -90
    for (const [x, y] of coords) {
      if (x < minX) minX = x
      if (x > maxX) maxX = x
      if (y < minY) minY = y
      if (y > maxY) maxY = y
    }
    return [[minX, minY], [maxX, maxY]]
  }

  buildLegend() {
    const el = this.element.querySelector("#service-map-legend")
    if (!el) return
    el.innerHTML = `
      <div class="legend-row"><span class="swatch" style="background:#5DADE2"></span> Tuesday</div>
      <div class="legend-row"><span class="swatch" style="background:#58D68D"></span> Wednesday</div>
      <div class="legend-row"><span class="swatch" style="background:#F5B041"></span> Thursday</div>
      <div class="legend-row"><span class="swatch" style="background:#BDC3C7"></span> Not yet serviced</div>
    `
  }

  enableDayFilters() {
    const buttons = this.element.querySelectorAll("[data-day-filter]")
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
