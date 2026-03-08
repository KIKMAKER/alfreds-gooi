import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["options", "plan"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isCommercial = this.planTarget.value === "Commercial"
    this.optionsTarget.style.display = isCommercial ? "block" : "none"
  }
}
