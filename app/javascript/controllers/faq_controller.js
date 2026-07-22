import { Controller } from "@hotwired/stimulus"

// Simple accordion — each item toggles independently (not single-open).
// Keyboard-operable for free since it's driven off a real <button>.
export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const item = event.currentTarget.closest("[data-faq-target='item']")
    const isOpen = item.classList.toggle("faq-item--open")
    event.currentTarget.setAttribute("aria-expanded", isOpen)
  }
}
