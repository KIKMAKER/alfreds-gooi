import { Controller } from "@hotwired/stimulus"

// Plan toggle (Standard/XL, existing) + duration selector (new — defaults
// to 6 months both server-side via the `hide` class already on the 1/3
// month cards in the view, and client-side here).
export default class extends Controller {
  static targets = ["title", "standard", "extra"]

  toggle() {
    this.titleTarget.innerText = this.titleTarget.innerText === "Standard" ? "XL" : "Standard"
    this.standardTarget.classList.toggle("hide")
    this.extraTarget.classList.toggle("hide")
  }

  selectDuration(event) {
    const duration = event.currentTarget.dataset.duration

    this.element.querySelectorAll("[data-duration-pill]").forEach((pill) => {
      pill.classList.toggle("duration-pill--active", pill.dataset.duration === duration)
    })

    this.element.querySelectorAll(".month-card").forEach((card) => {
      card.classList.toggle("hide", card.dataset.duration !== duration)
    })
  }
}
