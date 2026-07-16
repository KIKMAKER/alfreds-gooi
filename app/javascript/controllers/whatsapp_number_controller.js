import { Controller } from "@hotwired/stimulus"

// Live-formats a WhatsApp number field as the customer types: converts a
// leading 0 to South Africa's +27 country code and groups digits, e.g.
// "0821234567" becomes "+27 82 123 4567" while typing.
export default class extends Controller {
  connect() {
    this.element.addEventListener("input", this.format.bind(this))
  }

  format() {
    const raw = this.element.value
    const hasPlus = raw.trim().startsWith("+")
    let digits = raw.replace(/\D/g, "")

    if (!hasPlus && digits.startsWith("0")) {
      digits = `27${digits.slice(1)}`
    }

    if (digits.startsWith("27")) {
      const rest = digits.slice(2, 11)
      const parts = [rest.slice(0, 2), rest.slice(2, 5), rest.slice(5, 9)].filter(Boolean)
      this.element.value = parts.length ? `+27 ${parts.join(" ")}` : "+27"
    } else if (digits.length) {
      this.element.value = `+${digits}`
    } else {
      this.element.value = ""
    }
  }
}
