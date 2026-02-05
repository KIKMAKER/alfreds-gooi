import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  static values = {
    formName: String,    // "registration", "subscription", etc.
    plan: String,        // Subscription plan if available
    duration: String     // Subscription duration if available
  }

  connect() {
    this.formStarted = false
    this.formCompleted = false
    this.fieldsCompleted = new Set()
    this.startTime = Date.now()

    // Track form view (user saw the form)
    this.trackEvent("Viewed Registration Form", {
      plan: this.planValue,
      duration: this.durationValue
    })

    // Set up beforeunload to catch abandonment
    this.boundHandleBeforeUnload = this.handleBeforeUnload.bind(this)
    window.addEventListener("beforeunload", this.boundHandleBeforeUnload)
  }

  disconnect() {
    // Cleanup event listener
    window.removeEventListener("beforeunload", this.boundHandleBeforeUnload)
  }

  // Track when user first interacts with form
  fieldFocus(event) {
    const fieldName = event.target.name || event.target.id

    if (!this.formStarted) {
      this.formStarted = true
      this.trackEvent("Started Registration Form", {
        first_field: fieldName,
        plan: this.planValue,
        duration: this.durationValue
      })
    }
  }

  // Track field completion
  fieldBlur(event) {
    const fieldName = event.target.name || event.target.id
    const fieldValue = event.target.value

    // Only track if field has value
    if (fieldValue && fieldValue.trim().length > 0) {
      if (!this.fieldsCompleted.has(fieldName)) {
        this.fieldsCompleted.add(fieldName)

        // Track progress milestone
        if (this.fieldsCompleted.size === 1) {
          this.trackEvent("Completed First Field", { field: fieldName })
        } else if (this.fieldsCompleted.size === 4) {
          this.trackEvent("Completed Personal Info", {
            fields_completed: Array.from(this.fieldsCompleted).join(", ")
          })
        }
      }
    }
  }

  // Handle form submission (successful completion)
  formSubmit() {
    this.formCompleted = true

    const timeSpent = Math.round((Date.now() - this.startTime) / 1000)

    this.trackEvent("Completed Registration Form", {
      time_spent_seconds: timeSpent,
      fields_completed: this.fieldsCompleted.size,
      plan: this.planValue,
      duration: this.durationValue
    })
  }

  // Handle page navigation without submission (abandonment)
  handleBeforeUnload() {
    if (this.formStarted && !this.formCompleted) {
      const timeSpent = Math.round((Date.now() - this.startTime) / 1000)

      // Track abandonment event
      if (window.ahoy) {
        window.ahoy.track("Abandoned Registration Form", {
          time_spent_seconds: timeSpent,
          fields_completed: this.fieldsCompleted.size,
          completed_fields: Array.from(this.fieldsCompleted).join(", "),
          plan: this.planValue,
          duration: this.durationValue
        })
      }
    }
  }

  // Helper method to send events to Ahoy
  trackEvent(eventName, properties = {}) {
    if (window.ahoy) {
      window.ahoy.track(eventName, properties)
    }
  }
}
