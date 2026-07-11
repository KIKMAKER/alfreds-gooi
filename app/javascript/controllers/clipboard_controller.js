import { Controller } from "@hotwired/stimulus"

// Copies a block of text to the clipboard and flashes confirmation on the button.
// Usage:
//   <div data-controller="clipboard" data-clipboard-text-value="...">
//     <button data-action="clipboard#copy">Copy</button>
//   </div>
export default class extends Controller {
  static values = { text: String, successLabel: { type: String, default: "Copied!" } }

  async copy(event) {
    event.preventDefault()

    const button = event.currentTarget
    const original = button.innerHTML

    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      this.fallbackCopy()
    }

    button.innerHTML = this.successLabelValue
    setTimeout(() => { button.innerHTML = original }, 2000)
  }

  // navigator.clipboard is unavailable on insecure origins and older mobile
  // browsers, so drop back to a throwaway textarea + execCommand.
  fallbackCopy() {
    const textarea = document.createElement("textarea")
    textarea.value = this.textValue
    textarea.setAttribute("readonly", "")
    textarea.style.position = "absolute"
    textarea.style.left = "-9999px"

    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
  }
}
