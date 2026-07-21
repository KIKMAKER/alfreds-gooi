import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suburbSelect", "dateContainer", "dateSelect"]

  static values = {
    collectionDays: { type: Object, default: {} },
    selectedDate:   { type: String, default: "" }
  }

  connect() {
    if (this.suburbSelectTarget.value) {
      this.populateDates(this.suburbSelectTarget.value)
      if (this.selectedDateValue) {
        this.dateSelectTarget.value = this.selectedDateValue
      }
    }
  }

  suburbChanged(event) {
    const suburbId = event.target.value
    if (suburbId) {
      this.populateDates(suburbId)
    } else {
      this.dateContainerTarget.hidden = true
      this.dateSelectTarget.innerHTML = ""
    }
  }

  populateDates(suburbId) {
    const dayName = this.collectionDayFor(suburbId)
    if (!dayName) { this.dateContainerTarget.hidden = true; return }

    const dates = this.nextCollectionDates(dayName, 8, 3)
    this.dateSelectTarget.innerHTML = dates.map(date => {
      const iso = this.toIso(date)
      const display = date.toLocaleDateString("en-ZA", {
        weekday: "long", day: "numeric", month: "long", year: "numeric"
      })
      return `<option value="${iso}">${display}</option>`
    }).join("")

    this.dateContainerTarget.hidden = false
  }

  collectionDayFor(suburbId) {
    return this.collectionDaysValue[suburbId] || null
  }

  nextCollectionDates(dayName, count, leadDays) {
    const DOW = { Sunday: 0, Monday: 1, Tuesday: 2, Wednesday: 3, Thursday: 4, Friday: 5, Saturday: 6 }
    const targetDow = DOW[dayName]
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const earliest = new Date(today); earliest.setDate(today.getDate() + leadDays)
    const diff = (targetDow - earliest.getDay() + 7) % 7
    earliest.setDate(earliest.getDate() + diff)

    return Array.from({ length: count }, (_, i) => {
      const d = new Date(earliest); d.setDate(earliest.getDate() + i * 7); return d
    })
  }

  toIso(date) {
    // Local date components avoid UTC midnight shifting to previous day in SAST (+2)
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, "0")
    const d = String(date.getDate()).padStart(2, "0")
    return `${y}-${m}-${d}`
  }
}
