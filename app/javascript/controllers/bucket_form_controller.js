import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "gooi_bucket_size"
const SIZES = ["25", "45", "80"]

export default class extends Controller {
  static targets = ["grossInput", "netPreview", "btn25", "btn45", "btn80", "sizeField", "halfField", "halfLabel", "woodShavingsField", "woodShavingsLabel"]
  static values = { tare25: Number, tare45: Number, tare80: Number }

  connect() {
    const saved = localStorage.getItem(STORAGE_KEY) || "25"
    this._applySize(saved)
    this._updatePreview()
  }

  selectSize(event) {
    const size = event.currentTarget.dataset.bucketSize
    this._applySize(size)
    localStorage.setItem(STORAGE_KEY, size)
    this._updatePreview()
  }

  grossChanged() {
    this._updatePreview()
  }

  toggleHalf() {
    const checked = this.halfFieldTarget.checked
    this.halfLabelTarget.textContent = checked ? "Half-full ½" : "Full bucket"
    this.halfLabelTarget.classList.toggle("bucket-half-btn--active", checked)
  }

  toggleWoodShavings() {
    const checked = this.woodShavingsFieldTarget.checked
    this.woodShavingsLabelTarget.classList.toggle("bucket-wood-shavings-btn--active", checked)
  }

  _applySize(size) {
    this.sizeFieldTarget.value = size
    SIZES.forEach((s) => {
      this[`btn${s}Target`].classList.toggle("bucket-size-btn--active", s === size)
    })
  }

  _tareFor(size) {
    return this[`tare${size}Value`]
  }

  _updatePreview() {
    const gross = parseFloat(this.grossInputTarget.value)
    if (isNaN(gross) || gross <= 0) {
      this.netPreviewTarget.textContent = "—"
      this.netPreviewTarget.classList.remove("bucket-net-preview--ready")
      return
    }
    const size = this.sizeFieldTarget.value
    const tare = this._tareFor(size)
    const net = Math.max(0, gross - tare).toFixed(2)
    this.netPreviewTarget.textContent = `${net} kg net`
    this.netPreviewTarget.classList.add("bucket-net-preview--ready")
  }
}
