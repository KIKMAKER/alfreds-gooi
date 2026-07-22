import { Controller } from "@hotwired/stimulus"

// Generic open/close modal — used by the "Don't see your suburb?" waitlist
// prompt so the form doesn't have to take up a full homepage section.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.classList.add("modal--open")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.dialogTarget.classList.remove("modal--open")
    document.body.style.overflow = ""
  }

  closeBackground(event) {
    if (event.target === event.currentTarget) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
