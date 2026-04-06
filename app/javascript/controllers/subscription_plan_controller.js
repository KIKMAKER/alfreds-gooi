import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["durationField", "dateField", "commercialField"]

  connect() {
    const select = this.element.querySelector("select[name*='[plan]']")
    if (select) this.toggle(select.value)
  }

  planChanged(event) {
    this.toggle(event.target.value)
  }

  toggle(plan) {
    const isOnceOff    = plan === "once_off"
    const isCommercial = plan === "Commercial"
    this.durationFieldTarget.style.display  = isOnceOff ? "none" : ""
    this.dateFieldTarget.style.display      = isOnceOff ? ""     : "none"
    this.commercialFieldTarget.style.display = isCommercial ? "" : "none"
  }
}
