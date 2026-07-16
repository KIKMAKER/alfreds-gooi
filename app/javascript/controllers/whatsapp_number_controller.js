import { Controller } from "@hotwired/stimulus"

// Country-code dropdown for WhatsApp number fields, defaulting to South
// Africa. No third-party phone library — this app has no JS bundler, and
// the standard libraries (e.g. intl-tel-input) run libphonenumber in a
// Web Worker that doesn't load reliably over an importmap CDN pin, which
// froze the page. This is a small native <select> instead: the customer
// picks their own country so a foreign number never gets guessed at, and
// the dial code + digits are combined into the real field on submit.
//
// minDigits/maxDigits are a rough national-significant-number length per
// country, only for instant client-side feedback - not a substitute for
// the server-side phonelib validation, which is the real authority.
const COUNTRIES = [
  ["+27", "🇿🇦", "South Africa", 9, 9],
  ["+264", "🇳🇦", "Namibia", 9, 9],
  ["+267", "🇧🇼", "Botswana", 7, 8],
  ["+263", "🇿🇼", "Zimbabwe", 9, 9],
  ["+258", "🇲🇿", "Mozambique", 9, 9],
  ["+44", "🇬🇧", "United Kingdom", 10, 10],
  ["+1", "🇺🇸", "United States / Canada", 10, 10],
  ["+61", "🇦🇺", "Australia", 9, 9],
  ["+49", "🇩🇪", "Germany", 10, 11],
  ["+31", "🇳🇱", "Netherlands", 9, 9],
  ["+33", "🇫🇷", "France", 9, 9],
  ["", "🌍", "Other — type full number with +", null, null],
]

export default class extends Controller {
  connect() {
    this.buildCountrySelect()
    this.splitExistingValue()
    this.feedback = this.findOrBuildFeedback()

    this.inputHandler = this.validate.bind(this)
    this.element.addEventListener("input", this.inputHandler)
    this.select.addEventListener("change", this.inputHandler)

    this.form = this.element.closest("form")
    this.submitHandler = this.combine.bind(this)
    this.form?.addEventListener("submit", this.submitHandler)

    // Only run our own check if the server hasn't already flagged this
    // field - a server error is more specific than our length heuristic.
    if (!this.element.classList.contains("is-invalid")) this.validate()
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.submitHandler)
    this.element.removeEventListener("input", this.inputHandler)
    this.select?.removeEventListener("change", this.inputHandler)
    this.select?.remove()
  }

  // Only ever adds a new sibling before the field - never detaches or
  // moves `this.element` itself, since it's the controller's own root
  // node and relocating it risks Stimulus treating the move as a
  // disconnect+reconnect, which would run this method again forever.
  buildCountrySelect() {
    this.select = document.createElement("select")
    this.select.className = "form-select whatsapp-number__country"
    this.select.setAttribute("aria-label", "Country code")

    COUNTRIES.forEach(([dial, flag, name]) => {
      const option = document.createElement("option")
      option.value = dial
      option.title = name
      option.textContent = dial ? `${flag} ${dial}` : `${flag} Other`
      this.select.appendChild(option)
    })
    this.select.value = "+27"

    this.element.insertAdjacentElement("beforebegin", this.select)
    this.element.classList.add("whatsapp-number__input")
  }

  findOrBuildFeedback() {
    const next = this.element.nextElementSibling
    if (next?.classList.contains("invalid-feedback")) return next

    const div = document.createElement("div")
    div.className = "invalid-feedback"
    this.element.insertAdjacentElement("afterend", div)
    return div
  }

  splitExistingValue() {
    const value = this.element.value.trim()
    if (!value.startsWith("+")) return

    const match = COUNTRIES.find(([dial]) => dial && value.startsWith(dial))
    if (match) {
      this.select.value = match[0]
      this.element.value = value.slice(match[0].length).trim()
    } else {
      this.select.value = ""
    }
  }

  validate() {
    this.element.classList.remove("is-invalid", "is-valid")

    const digits = this.element.value.replace(/\D/g, "")
    if (!digits) return

    const [, , name, min, max] = COUNTRIES.find(([dial]) => dial === this.select.value)
    if (min === null) return // "Other" - no length data, defer to server

    if (digits.length < min || digits.length > max) {
      this.feedback.textContent = `${name} numbers usually have ${min === max ? min : `${min}-${max}`} digits after the country code - you've entered ${digits.length}.`
      this.element.classList.add("is-invalid")
    } else {
      this.element.classList.add("is-valid")
    }
  }

  combine() {
    const raw = this.element.value.trim()
    if (!raw || raw.startsWith("+")) return

    const dial = this.select.value
    const national = raw.replace(/^0+/, "")
    this.element.value = dial ? `${dial}${national}` : `+${raw.replace(/\D/g, "")}`
  }
}
