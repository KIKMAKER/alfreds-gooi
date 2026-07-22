import { Controller } from "@hotwired/stimulus"

// Counts each target up from 0 to its data-counter-value on connect. Respects
// prefers-reduced-motion by leaving the server-rendered static number as-is.
// Usage:
//   <div data-controller="counter">
//     <span data-counter-target="number" data-counter-value="230" data-counter-prefix="~" data-counter-suffix="kg">~230kg</span>
//   </div>
export default class extends Controller {
  static targets = ["number"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.numberTargets.forEach((el) => this.animate(el))
  }

  animate(el) {
    const value = Number(el.dataset.counterValue)
    const prefix = el.dataset.counterPrefix || ""
    const suffix = el.dataset.counterSuffix || ""
    const duration = 1200
    const start = performance.now()

    const step = (now) => {
      const progress = Math.min((now - start) / duration, 1)
      const current = Math.round(value * progress)
      el.textContent = `${prefix}${current.toLocaleString()}${suffix}`
      if (progress < 1) requestAnimationFrame(step)
    }

    requestAnimationFrame(step)
  }
}
