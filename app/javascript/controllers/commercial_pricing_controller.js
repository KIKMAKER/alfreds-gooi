import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["buckets", "price", "estimate"]
  static values = { renewal: Boolean }

  connect() {
    console.log("Commercial pricing controller connected")
    this.calculate()
  }

  calculate() {
    // Check for both 'duration' (signup) and 'commercial_duration' (renewal) radio buttons
    const duration = parseInt(
      document.querySelector('input[name="duration"]:checked')?.value ||
      document.querySelector('input[name="commercial_duration"]:checked')?.value ||
      12
    )
    const buckets = parseInt(this.bucketsTarget.value || 1)

    console.log("Calculating with duration:", duration, "buckets:", buckets, "renewal:", this.renewalValue)

    // Monthly rates based on duration
    const monthlyRates = {
      12: 200,
      6: 220,
      3: 240
    }

    // Volume charge per 45L bucket per collection (duration-specific)
    const volumeRates = {
      12: 24,
      6: 27,
      3: 30
    }

    // Starter kit cost per bucket
    const starterKitPerBucket = 300  // R300 per 45L bucket

    // Calculate
    const monthlyRate = monthlyRates[duration]
    const volumePerBucket = volumeRates[duration]
    const totalCollections = Math.round((duration * 52) / 12)  // Weekly collections
    const totalMonthlyFees = monthlyRate * duration
    const totalVolumeFees = buckets * volumePerBucket * totalCollections
    const starterKitCost = this.renewalValue ? 0 : (buckets * starterKitPerBucket)
    const grandTotal = totalMonthlyFees + totalVolumeFees + starterKitCost

    // Update the price display
    let priceHTML = ''

    if (!this.renewalValue) {
      priceHTML += `<small class="d-block">Starter kit: ${buckets} buckets × R${starterKitPerBucket} = R${starterKitCost.toFixed(2)}</small>`
    }

    priceHTML += `
      <small class="d-block">Monthly collection fee: R${monthlyRate} × ${duration} months = R${totalMonthlyFees.toFixed(2)}</small>
      <small class="d-block">Volume charge: ${buckets} buckets × ${totalCollections} collections × R${volumePerBucket} = R${totalVolumeFees.toFixed(2)}</small>
      <strong class="d-block mt-2">Total: R${grandTotal.toFixed(2)}</strong>
    `

    this.priceTarget.innerHTML = priceHTML

    // Update hidden fields
    const durationField = document.getElementById('subscription_duration')
    const bucketsField = document.getElementById('subscription_buckets')

    console.log("Duration field:", durationField)
    console.log("Buckets field:", bucketsField)

    if (durationField) {
      durationField.value = duration
      console.log("Set duration field to:", duration)
    } else {
      console.error("Could not find duration field with id 'subscription_duration'")
    }

    if (bucketsField) {
      bucketsField.value = buckets
      console.log("Set buckets field to:", buckets)
    } else {
      console.error("Could not find buckets field with id 'subscription_buckets'")
    }
  }
}
