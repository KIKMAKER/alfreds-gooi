import { Controller } from "@hotwired/stimulus"

// Injects the discount code as a hidden field into all subscription forms on submit
export default class extends Controller {
  static targets = ["input"]

  connect() {
    document.querySelectorAll("form").forEach(form => {
      form.addEventListener("submit", this.inject.bind(this, form))
    })
  }

  inject(form) {
    const code = this.inputTarget.value.trim()
    if (!code) return

    // Avoid duplicates if the form is submitted multiple times
    if (form.querySelector('[name="subscription[discount_code]"]')) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "subscription[discount_code]"
    hidden.value = code
    form.appendChild(hidden)
  }
}
