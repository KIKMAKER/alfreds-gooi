import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static targets = ["button", "status", "timer", "siteName"]
  static values = {
    driversDay: Number,
    currentDropOff: Number,
    arrivalTime: String,
    siteName: String
  }

  connect() {
    console.log("Drop-off timer controller connected!")
    console.log("Drivers Day ID:", this.driversDayValue)
    console.log("Current Drop-off ID:", this.currentDropOffValue)

    this.timerInterval = null
    this.updateDisplay()

    if (this.hasArrivalTime()) {
      this.startTimer()
    }
  }

  disconnect() {
    this.stopTimer()
  }

  hasArrivalTime() {
    return this.arrivalTimeValue && this.arrivalTimeValue !== ""
  }

  // Called when a drop-off row is clicked
  async selectDropOff(event) {
    console.log("selectDropOff called!", event.currentTarget)
    const dropOffId = event.currentTarget.dataset.dropOffId
    console.log("Drop-off ID:", dropOffId)

    const response = await post(
      `/drivers_days/${this.driversDayValue}/set_current_drop_off/${dropOffId}`,
      { responseKind: "json" }
    )

    if (response.ok) {
      const data = await response.json
      console.log("Drop-off selected:", data)
      this.currentDropOffValue = data.drop_off_event.id
      this.siteNameValue = data.drop_off_event.name
      this.arrivalTimeValue = data.drop_off_event.arrival_time || ""

      this.updateDisplay()

      if (data.drop_off_event.has_arrival && !data.drop_off_event.has_departure) {
        console.log("Resuming timer from existing arrival time")
        this.startTimer()
      }
    } else {
      console.error("Failed to select drop-off", response)
    }
  }

  async recordArrival() {
    if (!this.currentDropOffValue) {
      alert("Please select a drop-off first")
      return
    }

    const response = await post(
      `/drivers_days/${this.driversDayValue}/drop_off_events/${this.currentDropOffValue}/record_arrival`,
      { responseKind: "json" }
    )

    if (response.ok) {
      const data = await response.json
      console.log("Arrival recorded!", data)
      this.arrivalTimeValue = data.arrival_time
      this.updateDisplay()
      this.startTimer()
    } else {
      console.error("Failed to record arrival", response)
    }
  }

  async recordDeparture() {
    const response = await post(
      `/drivers_days/${this.driversDayValue}/drop_off_events/${this.currentDropOffValue}/record_departure`,
      { responseKind: "json" }
    )

    if (response.ok) {
      const data = await response.json
      console.log("Departure recorded!", data)
      console.log("Duration:", data.duration_minutes, "minutes")
      this.stopTimer()
      this.arrivalTimeValue = ""
      this.currentDropOffValue = 0
      this.updateDisplay()

      // Show success message briefly
      this.showSuccess(data.message)
    } else {
      console.error("Failed to record departure", response)
    }
  }

  updateDisplay() {
    if (!this.currentDropOffValue) {
      // No drop-off selected
      this.buttonTarget.textContent = "Select drop-off"
      this.buttonTarget.disabled = true
      this.statusTarget.textContent = "Tap a drop-off to start timing"
    } else if (!this.hasArrivalTime()) {
      // Drop-off selected, not arrived yet
      this.siteNameTarget.textContent = this.siteNameValue
      this.buttonTarget.textContent = "I'm Here"
      this.buttonTarget.disabled = false
      this.buttonTarget.onclick = () => this.recordArrival()
      this.statusTarget.textContent = "Ready to record arrival"
    } else {
      // Arrived, waiting for departure
      this.siteNameTarget.textContent = this.siteNameValue
      this.buttonTarget.textContent = "Leaving"
      this.buttonTarget.disabled = false
      this.buttonTarget.onclick = () => this.recordDeparture()
      this.statusTarget.textContent = "Timer running..."
    }
  }

  startTimer() {
    this.stopTimer() // Clear any existing timer

    this.timerInterval = setInterval(() => {
      const elapsed = this.calculateElapsed()
      this.timerTarget.textContent = this.formatDuration(elapsed)
    }, 1000)
  }

  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }
    this.timerTarget.textContent = ""
  }

  calculateElapsed() {
    if (!this.arrivalTimeValue) return 0

    const arrival = new Date(this.arrivalTimeValue)
    const now = new Date()
    return Math.floor((now - arrival) / 1000) // seconds
  }

  formatDuration(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  showSuccess(message) {
    // Optionally show a toast/notification
    this.statusTarget.textContent = message
    setTimeout(() => this.updateDisplay(), 3000)
  }
}
