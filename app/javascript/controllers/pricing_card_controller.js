import { Controller } from "@hotwired/stimulus"

// Independent 1/3/6-month duration toggle scoped to a single pricing card
// (Standard or XL) — each card has its own instance, so choosing a
// duration on one card doesn't affect the other. Defaults to 6 months via
// the `hide` class already on the 1/3-month panels server-side.
export default class extends Controller {
  static targets = ["panel", "pill"]

  select(event) {
    const duration = event.currentTarget.dataset.duration

    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("duration-pill--active", pill.dataset.duration === duration)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hide", panel.dataset.duration !== duration)
    })
  }
}
