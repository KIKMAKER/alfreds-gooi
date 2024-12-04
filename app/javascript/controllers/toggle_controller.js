import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["form", "button"]

  fire() {
    this.formTarget.classList.toggle("d-none");
    this.buttonTarget.classList.toggle("d-none");
  }
}
