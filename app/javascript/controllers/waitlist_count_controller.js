import { Controller } from "@hotwired/stimulus"

// "Seed #N" nudge for the waitlist form — derived entirely from existing
// Interest records grouped by suburb_id (PagesController#home), no schema
// change. Shows nothing for the blank "Other" option, since there's no
// suburb to count against.
export default class extends Controller {
  static targets = ["select", "line"]
  static values = { counts: Object }

  update() {
    const suburbId = this.selectTarget.value
    const option = this.selectTarget.options[this.selectTarget.selectedIndex]
    const suburbName = option ? option.text : ""

    if (!suburbId) {
      this.lineTarget.textContent = ""
      return
    }

    const count = (this.countsValue[suburbId] || 0) + 1
    this.lineTarget.textContent = `You'd be neighbour #${count} asking in ${suburbName}.`
  }
}
