import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";
import { patch } from "@rails/request.js";

// Connects to data-controller="sortable"
//
// Saves the dragged order to `url`. Saves are serialised: only one request is in
// flight at a time, and if the driver keeps dragging meanwhile only the newest
// order is sent next. That stops a slow older request from landing after (and
// overwriting) a newer one. A failed save retries, then shows a tappable error —
// it never leaves a list that looks saved but isn't.
export default class extends Controller {
  static values = { url: String }

  static RETRY_DELAYS_MS = [800, 2000, 4000]

  connect() {
    this.pending = null
    this.saving = false
    this.failedItems = null
    this.statusElement = this.buildStatusElement()
    this.guardUnload = this.guardUnload.bind(this)
    window.addEventListener("beforeunload", this.guardUnload)

    this.sortable = new Sortable(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",
      draggable: ".sortable-item",
      handle: ".drag-handle",
      delay: 200,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      onEnd: this.onEnd.bind(this),
    })
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.guardUnload)
    this.sortable.destroy()
    this.statusElement?.remove()
  }

  onEnd(event) {
    // A drop back where it started changes nothing — don't spend a request on it.
    if (event && event.oldIndex === event.newIndex) return
    this.queue(this.currentItems())
  }

  queue(items) {
    if (!this.hasUrlValue) return
    this.pending = items
    this.failedItems = null
    this.flush()
  }

  currentItems() {
    return Array.from(this.element.querySelectorAll(".sortable-item"))
      .map(el => ({ type: el.dataset.sortableType, id: el.dataset.sortableId }))
  }

  async flush() {
    if (this.saving) return // the running loop will pick up this.pending

    this.saving = true
    try {
      while (this.pending) {
        const items = this.pending
        this.pending = null
        this.showStatus("saving")
        if (await this.save(items)) {
          if (!this.pending) this.showStatus("saved")
        } else {
          // A newer order may already be waiting; only report failure if it isn't.
          if (!this.pending) {
            this.failedItems = items
            this.showStatus("error")
          }
        }
      }
    } finally {
      this.saving = false
    }
  }

  async save(items) {
    const delays = [0, ...this.constructor.RETRY_DELAYS_MS]
    for (const delay of delays) {
      if (delay) await new Promise(resolve => setTimeout(resolve, delay))
      if (this.pending) return true // superseded by a newer drag; it will be saved instead

      try {
        const response = await patch(this.urlValue, {
          body: JSON.stringify({ items }),
          contentType: "application/json",
          responseKind: "json",
        })
        // A login redirect ends in a 200 HTML page, so ok alone isn't proof.
        if (response.ok && !response.redirected) return true
        if ([401, 403, 404, 422].includes(response.statusCode)) return false // retrying won't help
      } catch (_error) {
        // network drop — fall through and retry
      }
    }
    return false
  }

  retry() {
    if (this.failedItems) this.queue(this.failedItems)
  }

  guardUnload(event) {
    if (this.saving || this.pending || this.failedItems) {
      event.preventDefault()
      event.returnValue = ""
    }
  }

  buildStatusElement() {
    const element = document.createElement("div")
    element.className = "route-save-status"
    element.setAttribute("role", "status")
    element.hidden = true
    element.addEventListener("click", () => this.retry())
    this.element.insertAdjacentElement("beforebegin", element)
    return element
  }

  showStatus(state) {
    clearTimeout(this.hideTimer)
    const messages = {
      saving: "Saving route order…",
      saved: "Route order saved ✓",
      error: "Couldn't save the route order — tap to retry",
    }
    this.statusElement.className = `route-save-status route-save-status--${state}`
    this.statusElement.textContent = messages[state]
    this.statusElement.hidden = false
    if (state === "saved") {
      this.hideTimer = setTimeout(() => { this.statusElement.hidden = true }, 2000)
    }
  }
}
