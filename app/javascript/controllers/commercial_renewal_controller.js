import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "buckets"]

  connect() {
    console.log("Commercial renewal controller connected")
    // Initial update when page loads
    this.updateForm()

    // Add submit handler to log form data
    this.formTarget.addEventListener('submit', (e) => {
      console.log("=== FORM SUBMITTING ===")
      console.log("Form element:", this.formTarget)
      const formData = new FormData(this.formTarget)
      console.log("Form data:")
      for (let [key, value] of formData.entries()) {
        console.log(`  ${key}: ${value}`)
      }
    })
  }

  updateForm(event) {
    console.log("=== updateForm called ===", event ? "by event" : "on connect")

    const durationRadio = document.querySelector('input[name="commercial_duration"]:checked')
    const bucketSizeRadio = document.querySelector('input[name="commercial_bucket_size"]:checked')
    const bucketsInput = this.bucketsTarget

    console.log("Found elements:", {
      durationRadio: durationRadio,
      durationValue: durationRadio?.value,
      bucketSizeRadio: bucketSizeRadio,
      bucketSizeValue: bucketSizeRadio?.value,
      bucketsInput: bucketsInput,
      bucketsValue: bucketsInput?.value
    })

    const selectedDuration = durationRadio?.value || '12'
    const selectedBucketSize = bucketSizeRadio?.value || '45'
    const selectedBuckets = bucketsInput?.value || '1'

    console.log("Selected values:", { selectedDuration, selectedBucketSize, selectedBuckets })
    console.log("Form target:", this.formTarget)

    // Find or create hidden input for duration
    let durationInput = this.formTarget.querySelector('input[name="subscription[duration]"]')
    const oldDurationValue = durationInput?.value
    if (!durationInput) {
      console.log("Creating new duration input")
      durationInput = document.createElement('input')
      durationInput.type = 'hidden'
      durationInput.name = 'subscription[duration]'
      this.formTarget.appendChild(durationInput)
    }
    durationInput.value = selectedDuration
    console.log(`Duration input: ${oldDurationValue} → ${durationInput.value}`)

    // Find or create hidden input for bucket_size
    let bucketSizeInput = this.formTarget.querySelector('input[name="subscription[bucket_size]"]')
    const oldBucketSize = bucketSizeInput?.value
    if (!bucketSizeInput) {
      console.log("Creating new bucket_size input")
      bucketSizeInput = document.createElement('input')
      bucketSizeInput.type = 'hidden'
      bucketSizeInput.name = 'subscription[bucket_size]'
      this.formTarget.appendChild(bucketSizeInput)
    }
    bucketSizeInput.value = selectedBucketSize
    console.log(`Bucket size input: ${oldBucketSize} → ${bucketSizeInput.value}`)

    // Find or create hidden input for buckets_per_collection
    let bucketsParamInput = this.formTarget.querySelector('input[name="subscription[buckets_per_collection]"]')
    const oldBucketsParam = bucketsParamInput?.value
    if (!bucketsParamInput) {
      console.log("Creating new buckets_per_collection input")
      bucketsParamInput = document.createElement('input')
      bucketsParamInput.type = 'hidden'
      bucketsParamInput.name = 'subscription[buckets_per_collection]'
      this.formTarget.appendChild(bucketsParamInput)
    }
    bucketsParamInput.value = selectedBuckets
    console.log(`Buckets param input: ${oldBucketsParam} → ${bucketsParamInput.value}`)

    console.log("=== Form updated successfully ===")
  }
}
