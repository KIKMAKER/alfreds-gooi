import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = {
    token: String,
    geoUrl: String,
    collectionDays: Object,
    suburbSlugs: Object
  }

  // Mapbox GL is a heavy bundle to load and render — defer it until the
  // map section actually nears the viewport instead of on every page load.
  connect() {
    if (!this.hasTokenValue || !this.hasGeoUrlValue) return

    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        this.observer.disconnect()
        this.initMap()
      }
    }, { rootMargin: "200px" })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  initMap() {
    // Precompute a normalized-name -> day lookup
    this.dayByStandardizedName = {}
    for (const [name, day] of Object.entries(this.collectionDaysValue || {})) {
      this.dayByStandardizedName[this.standardize(name)] = day
    }

    // Same idea for suburb page slugs, so a click can link to /suburbs/:slug
    // when one exists (active/waitlist-with-launch-date/target suburbs only —
    // see Suburb.publicly_visible).
    this.slugByStandardizedName = {}
    for (const [name, slug] of Object.entries(this.suburbSlugsValue || {})) {
      this.slugByStandardizedName[this.standardize(name)] = slug
    }

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

      // Fills — colours match config/_colors.scss ($red/$blue/$medium-green/
      // $orange). Mapbox paint expressions can't reference SCSS variables, so
      // these have to stay in sync by hand if the palette ever changes.
      this.map.addLayer({
        id: "areas-fill",
        type: "fill",
        source: "service-areas",
        paint: {
          "fill-color": [
            "match",
            ["get", "day"],
            "Monday",    "#bc4749", // $red
            "Tuesday",   "#0D6EFD", // $blue
            "Wednesday", "#108A63", // $medium-green
            "Thursday",  "#E67E22", // $orange
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
        const slug = this.slugByStandardizedName[this.standardize(name)]
        const link = slug ? `<br/><a href="/suburbs/${slug}">Visit suburb page &rarr;</a>` : ""
        new mapboxgl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`<strong>${name}</strong><br/>${day}${link}`)
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
    return this.dayByStandardizedName[this.standardize(name)] || null
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
      <div class="legend-row"><span class="swatch" style="background:#bc4749"></span> Monday</div>
      <div class="legend-row"><span class="swatch" style="background:#0D6EFD"></span> Tuesday</div>
      <div class="legend-row"><span class="swatch" style="background:#108A63"></span> Wednesday</div>
      <div class="legend-row"><span class="swatch" style="background:#E67E22"></span> Thursday</div>
      <div class="legend-row"><span class="swatch" style="background:#BDC3C7"></span> Not yet serviced</div>
    `
  }

  enableDayFilters() {
    const buttons = this.element.querySelectorAll("[data-day-filter]")
    buttons.forEach(btn => {
      btn.addEventListener("click", () => {
        buttons.forEach(b => b.classList.toggle("active", b === btn))

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
