import { Controller } from "@hotwired/stimulus"

const QUEUE_KEY = "festival_offline_queue"

// Connects to data-controller="festival-offline"
//
// Gives the festival waste tracker offline capability:
//   - Intercepts form submits when there is no network connection
//   - Stores pending entries in localStorage
//   - Auto-syncs the queue when the browser comes back online
//   - Shows a badge with the count of pending entries
export default class extends Controller {
  static targets = ["badge", "offlineBar", "status"]

  connect() {
    // Store bound references so we can remove the exact same function later
    this._onOnline  = () => this.syncQueue()
    this._onOffline = () => this.updateStatus()

    window.addEventListener("online",  this._onOnline)
    window.addEventListener("offline", this._onOffline)

    this.updateStatus()

    // If the page loads while online, attempt to drain any queue left from a
    // previous offline session (e.g. the phone got signal back overnight).
    if (navigator.onLine) this.syncQueue()
  }

  disconnect() {
    window.removeEventListener("online",  this._onOnline)
    window.removeEventListener("offline", this._onOffline)
  }

  // Wired to the form via: data-action="submit->festival-offline#interceptSubmit"
  interceptSubmit(event) {
    if (navigator.onLine) return  // Online: let Turbo handle the submit normally

    event.preventDefault()       // Stop Turbo from sending the request

    this.enqueue(event.target)
    this.updateStatus()
    this.showStatus("Saved — will sync automatically when signal returns.")
    event.target.reset()

    // Restore the datetime field to now so the next entry is pre-filled sensibly
    const timeField = event.target.querySelector("[name='logged_at']")
    if (timeField) {
      const now = new Date()
      now.setSeconds(0, 0)
      timeField.value = now.toISOString().slice(0, 16)
    }
  }

  enqueue(form) {
    const entries = [...new FormData(form).entries()]
    const data = {}
    entries.forEach(([k, v]) => {
      if (k !== "authenticity_token") data[k] = v
    })
    data._url       = form.action
    data._queued_at = new Date().toISOString()

    const queue = this.getQueue()
    queue.push(data)
    localStorage.setItem(QUEUE_KEY, JSON.stringify(queue))
  }

  async syncQueue() {
    const queue = this.getQueue()
    if (!queue.length) return

    const failed = []

    for (const entry of queue) {
      try {
        const body = new URLSearchParams()
        Object.entries(entry).forEach(([k, v]) => {
          if (!k.startsWith("_")) body.append(k, v)
        })

        const response = await fetch(entry._url, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body
        })

        // A redirect (3xx) followed by a 200 means the entry was accepted.
        // Any 4xx/5xx means something went wrong — keep the entry for retry.
        if (!response.ok && response.status >= 400) failed.push(entry)

      } catch {
        // Network error — keep entry for next attempt
        failed.push(entry)
      }
    }

    localStorage.setItem(QUEUE_KEY, JSON.stringify(failed))
    this.updateStatus()

    if (failed.length < queue.length) {
      // At least some entries synced — reload so they appear in the log
      window.location.reload()
    }
  }

  getQueue() {
    try {
      return JSON.parse(localStorage.getItem(QUEUE_KEY) || "[]")
    } catch {
      return []
    }
  }

  updateStatus() {
    const count  = this.getQueue().length
    const online = navigator.onLine

    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = `${count} pending`
      this.badgeTarget.hidden = count === 0
    }

    if (this.hasOfflineBarTarget) {
      this.offlineBarTarget.hidden = online
    }
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
    setTimeout(() => {
      if (this.hasStatusTarget) this.statusTarget.hidden = true
    }, 6000)
  }
}
