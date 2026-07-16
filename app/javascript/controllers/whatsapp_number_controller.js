import { Controller } from "@hotwired/stimulus"

// Country-code dropdown for WhatsApp number fields, defaulting to South
// Africa. No third-party phone library — this app has no JS bundler, and
// the standard libraries (e.g. intl-tel-input) run libphonenumber in a
// Web Worker that doesn't load reliably over an importmap CDN pin, which
// froze the page. This is a small native <select> instead: the customer
// picks their own country so a foreign number never gets guessed at, and
// the dial code + digits are combined into the real field on submit.
const COUNTRIES = [
  ["+27", "🇿🇦 South Africa"],
  ["+264", "🇳🇦 Namibia"],
  ["+267", "🇧🇼 Botswana"],
  ["+263", "🇿🇼 Zimbabwe"],
  ["+258", "🇲🇿 Mozambique"],
  ["+44", "🇬🇧 United Kingdom"],
  ["+1", "🇺🇸 United States / Canada"],
  ["+61", "🇦🇺 Australia"],
  ["+49", "🇩🇪 Germany"],
  ["+31", "🇳🇱 Netherlands"],
  ["+33", "🇫🇷 France"],
  ["", "🌍 Other — type full number with +"],
]

export default class extends Controller {
  connect() {
    this.buildCountrySelect()
    this.splitExistingValue()

    this.form = this.element.closest("form")
    this.submitHandler = this.combine.bind(this)
    this.form?.addEventListener("submit", this.submitHandler)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.submitHandler)
    this.select?.remove()
  }

  buildCountrySelect() {
    const wrapper = document.createElement("div")
    wrapper.className = "whatsapp-number"

    this.select = document.createElement("select")
    this.select.className = "form-select whatsapp-number__country"
    this.select.setAttribute("aria-label", "Country code")

    COUNTRIES.forEach(([dial, label]) => {
      const option = document.createElement("option")
      option.value = dial
      option.textContent = dial ? `${label} (${dial})` : label
      this.select.appendChild(option)
    })
    this.select.value = "+27"

    this.element.parentNode.insertBefore(wrapper, this.element)
    wrapper.appendChild(this.select)
    wrapper.appendChild(this.element)
    this.element.classList.add("whatsapp-number__input")
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

  combine() {
    const raw = this.element.value.trim()
    if (!raw || raw.startsWith("+")) return

    const dial = this.select.value
    const national = raw.replace(/^0+/, "")
    this.element.value = dial ? `${dial}${national}` : `+${raw.replace(/\D/g, "")}`
  }
}
