import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suburbSelect", "dateContainer", "dateSelect"]

  static values = {
    mondaySuburbs:    { type: Array, default: [] },
    tuesdaySuburbs:   { type: Array, default: [] },
    wednesdaySuburbs: { type: Array, default: [] },
    thursdaySuburbs:  { type: Array, default: [] },
    selectedDate:     { type: String, default: "" }
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
    const suburb = event.target.value
    if (suburb) {
      this.populateDates(suburb)
    } else {
      this.dateContainerTarget.hidden = true
      this.dateSelectTarget.innerHTML = ""
    }
  }

  populateDates(suburb) {
    const dayName = this.collectionDayFor(suburb)
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

  collectionDayFor(suburb) {
    // Priority order mirrors set_collection_day callback in subscription.rb
    if (this.mondaySuburbsValue.includes(suburb))    return "Monday"
    if (this.tuesdaySuburbsValue.includes(suburb))   return "Tuesday"
    if (this.wednesdaySuburbsValue.includes(suburb)) return "Wednesday"
    if (this.thursdaySuburbsValue.includes(suburb))  return "Thursday"
    return null
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
