import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "form"]

  pick() {
    const subId = this.selectTarget.value
    if (!subId) {
      this.formTarget.classList.add("d-none")
      return
    }
    this.formTarget.action = `/subscriptions/${subId}/collect_courtesy`
    this.formTarget.classList.remove("d-none")
  }
}
