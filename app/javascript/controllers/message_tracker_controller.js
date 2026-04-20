import { Controller } from "@hotwired/stimulus"

// Tracks which WhatsApp links Alfred has already opened, using localStorage.
// Storage key: "gooi-msg-{date}-{contactId}" — date-scoped so yesterday's state
// doesn't bleed into today's session.
export default class extends Controller {
  static targets = ["link", "status"]
  static values  = { date: String }

  connect() {
    this.linkTargets.forEach(link => {
      if (this.isSent(link)) this.markSent(link)
    })
  }

  track(event) {
    const link = event.currentTarget
    // Store immediately — the tab opens in a new window so we need to persist
    // before the browser switches focus.
    localStorage.setItem(this.storageKey(link), "1")
    // Small delay so the user sees the state change after returning
    setTimeout(() => this.markSent(link), 400)
  }

  markSent(link) {
    link.classList.add("msg-link--sent")
    const row = link.closest(".msg-row")
    if (row) row.classList.add("msg-row--sent")
  }

  isSent(link) {
    return !!localStorage.getItem(this.storageKey(link))
  }

  storageKey(link) {
    return `gooi-msg-${this.dateValue}-${link.dataset.contactId}`
  }
}
