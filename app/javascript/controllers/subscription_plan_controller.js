import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["durationField", "dateField"]

  connect() {
    const select = this.element.querySelector("select[name*='[plan]']")
    if (select) this.toggle(select.value)
  }

  planChanged(event) {
    this.toggle(event.target.value)
  }

  toggle(plan) {
    const isOnceOff = plan === "once_off"
    this.durationFieldTarget.style.display = isOnceOff ? "none" : ""
    this.dateFieldTarget.style.display     = isOnceOff ? ""     : "none"
  }
}
