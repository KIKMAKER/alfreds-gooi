import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = {
    token: String,
    dataUrl: String,
    initialDay: { type: String, default: "all" }
  }

  async connect() {
    if (!this.hasTokenValue || !this.hasDataUrlValue) return

    mapboxgl.accessToken = this.tokenValue
    await this.setupMap()
    await this.loadCustomerData()
  }

  async setupMap() {
    const container = this.element.querySelector('#customer-map')

    // Ensure container is empty (fixes Mapbox warning)
    container.innerHTML = ''

    this.map = new mapboxgl.Map({
      container: container,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [18.4241, -33.9249],  // Cape Town
      zoom: 10,
      maxBounds: [[17.8, -34.5], [19.0, -33.4]],
      minZoom: 9,
      dragRotate: false,
      touchZoomRotate: { rotate: false }
    })

    this.map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')
  }

  async loadCustomerData() {
    try {
      const response = await fetch(this.dataUrlValue, { cache: 'reload' })

      if (!response.ok) {
        console.error('Failed to load customer data:', response.status, response.statusText)
        return
      }

      const geojson = await response.json()

      if (!geojson || !geojson.features) {
        console.error('Invalid GeoJSON response:', geojson)
        return
      }

      const addMarkers = () => {
        this.addCustomerMarkers(geojson)
        this.fitMapToBounds(geojson)
      }

      // Check if map is already loaded
      if (this.map.loaded()) {
        addMarkers()
      } else {
        this.map.on('load', addMarkers)
      }
    } catch (error) {
      console.error('Error loading customer map data:', error)
    }
  }

  addCustomerMarkers(geojson) {
    // Add source with clustering
    this.map.addSource('customers', {
      type: 'geojson',
      data: geojson,
      cluster: true,
      clusterMaxZoom: 14,
      clusterRadius: 50
    })

    // Cluster circles
    this.map.addLayer({
      id: 'clusters',
      type: 'circle',
      source: 'customers',
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': [
          'step',
          ['get', 'point_count'],
          '#51bbd6', 10, '#f1f075', 30, '#f28cb1'
        ],
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          15, 10, 20, 30, 25
        ]
      }
    })

    // Cluster count labels
    this.map.addLayer({
      id: 'cluster-count',
      type: 'symbol',
      source: 'customers',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': '{point_count_abbreviated}',
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12
      }
    })

    // Individual markers (colored by day, sized by volume)
    this.map.addLayer({
      id: 'unclustered-point',
      type: 'circle',
      source: 'customers',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': [
          'match',
          ['get', 'collection_day'],
          'Monday', '#E74C3C',
          'Tuesday', '#5DADE2',
          'Wednesday', '#58D68D',
          'Thursday', '#F5B041',
          '#BDC3C7'
        ],
        'circle-radius': ['get', 'marker_size'],
        'circle-stroke-width': 1,
        'circle-stroke-color': '#fff',
        'circle-opacity': 0.8
      }
    })

    // Click handler for popups
    this.map.on('click', 'unclustered-point', (e) => {
      this.showPopup(e.features[0], e.lngLat)
    })

    // Cursor pointer on hover
    this.map.on('mouseenter', 'unclustered-point', () => {
      this.map.getCanvas().style.cursor = 'pointer'
    })
    this.map.on('mouseleave', 'unclustered-point', () => {
      this.map.getCanvas().style.cursor = ''
    })
  }

  showPopup(feature, lngLat) {
    const { customer_name, address, suburb, plan, avg_bags_weekly, avg_buckets_weekly, bucket_size, buckets_per_collection } = feature.properties

    let volumeInfo
    if (plan === 'Standard') {
      volumeInfo = `<p class="mb-0"><strong>Avg Weekly:</strong> ${avg_bags_weekly} bags</p>`
    } else if (plan === 'Commercial') {
      const literagePerWeek = avg_buckets_weekly * bucket_size
      volumeInfo = `
        <p class="mb-1"><strong>Config:</strong> ${buckets_per_collection} × ${bucket_size}L buckets</p>
        <p class="mb-0"><strong>Avg Weekly:</strong> ${avg_buckets_weekly} buckets (~${literagePerWeek}L)</p>
      `
    } else {
      // XL
      volumeInfo = `<p class="mb-0"><strong>Avg Weekly:</strong> ${avg_buckets_weekly} buckets</p>`
    }

    const html = `
      <div class="customer-popup">
        <strong>${customer_name}</strong>
        <p class="mb-1"><small>${address}, ${suburb}</small></p>
        <hr class="my-2">
        <p class="mb-1"><strong>Plan:</strong> ${plan}</p>
        ${volumeInfo}
      </div>
    `

    new mapboxgl.Popup()
      .setLngLat(lngLat)
      .setHTML(html)
      .addTo(this.map)
  }

  filterDay(event) {
    const day = event.currentTarget.dataset.day

    // Update button states
    this.element.querySelectorAll('[data-day]').forEach(btn => {
      btn.classList.remove('active')
    })
    event.currentTarget.classList.add('active')

    // Apply filter
    const filter = day === 'all' ? null : ['==', ['get', 'collection_day'], day]
    this.map.setFilter('unclustered-point', filter)
    this.map.setFilter('clusters', filter)
  }

  fitMapToBounds(geojson) {
    if (geojson.features.length === 0) return

    const bounds = new mapboxgl.LngLatBounds()
    geojson.features.forEach(feature => {
      bounds.extend(feature.geometry.coordinates)
    })
    this.map.fitBounds(bounds, { padding: 50 })
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
}
