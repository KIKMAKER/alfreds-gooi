import { Controller } from "@hotwired/stimulus"

// Detects the user's platform and shows the relevant install instructions.
// Also detects if the PWA is already installed (standalone display mode).

export default class extends Controller {
  static targets = [
    "ios", "android", "desktop", "done",
    "safariOk", "safariWarn"
  ]

  connect() {
    this.detect()
  }

  detect() {
    const ua = navigator.userAgent

    // ── Already installed? ──────────────────────────────────────────────────
    // iOS sets navigator.standalone when running from home screen.
    // All platforms: manifest display:standalone triggers this media query.
    const isStandalone =
      window.navigator.standalone === true ||
      window.matchMedia("(display-mode: standalone)").matches

    if (isStandalone) {
      this.show(this.doneTarget)
      return
    }

    // ── Platform detection ──────────────────────────────────────────────────
    const isIOS     = /iPad|iPhone|iPod/.test(ua) && !window.MSStream
    const isAndroid = /Android/.test(ua)

    if (isIOS) {
      this.show(this.iosTarget)
      this.checkSafari(ua)
    } else if (isAndroid) {
      this.show(this.androidTarget)
    } else {
      this.show(this.desktopTarget)
    }
  }

  // iOS requires Safari — Chrome/Firefox on iOS can't install PWAs.
  // CriOS = Chrome iOS, FxiOS = Firefox iOS, EdgiOS = Edge iOS, OPiOS = Opera iOS.
  checkSafari(ua) {
    const inSafari = /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS|OPiOS/.test(ua)

    if (inSafari) {
      this.show(this.safariOkTarget)
      this.safariWarnTarget.hidden = true
    } else {
      this.show(this.safariWarnTarget)
      this.safariOkTarget.hidden = true
    }
  }

  show(el) { el.hidden = false }
}
