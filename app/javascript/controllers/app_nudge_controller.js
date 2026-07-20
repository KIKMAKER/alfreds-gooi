import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="app-nudge"
// Shows a dismissible "get the app" nudge card after a short delay,
// unless already installed or dismissed within the last 30 days.

const DISMISS_KEY = "gooiAppNudgeDismissedAt"
const DISMISS_DAYS = 30
const SHOW_DELAY_MS = 5000

export default class extends Controller {
  connect() {
    if (this.isStandalone() || this.recentlyDismissed()) return

    this.timeout = setTimeout(() => {
      this.element.classList.add("visible")
    }, SHOW_DELAY_MS)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  isStandalone() {
    return (
      window.navigator.standalone === true ||
      window.matchMedia("(display-mode: standalone)").matches
    )
  }

  recentlyDismissed() {
    const dismissedAt = localStorage.getItem(DISMISS_KEY)
    if (!dismissedAt) return false

    const elapsedDays = (Date.now() - Number(dismissedAt)) / (1000 * 60 * 60 * 24)
    return elapsedDays < DISMISS_DAYS
  }

  dismiss(event) {
    event.preventDefault()
    this.element.classList.remove("visible")
    localStorage.setItem(DISMISS_KEY, Date.now())
  }
}
