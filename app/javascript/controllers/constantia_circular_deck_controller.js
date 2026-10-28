import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "counter", "prev", "next"]

  connect() {
    this.index = 0
    this.total = this.slideTargets.length
    this.show()
    this.onKeydown = (e) => {
      if (e.key === "ArrowRight" && this.index < this.total - 1) this.next()
      if (e.key === "ArrowLeft" && this.index > 0) this.prev()
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  prev() {
    this.index = (this.index - 1 + this.total) % this.total
    this.show()
  }

  next() {
    this.index = (this.index + 1) % this.total
    this.show()
  }

  show() {
    this.slideTargets.forEach((slide, i) => {
      slide.hidden = i !== this.index
    })
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `Slide ${this.index + 1} of ${this.total}`
    }
    if (this.hasPrevTarget) this.prevTarget.disabled = this.index === 0
    if (this.hasNextTarget) this.nextTarget.disabled = this.index === this.total - 1
  }
}
