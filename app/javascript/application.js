// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"

// Auto-dismiss flash alerts after 4 seconds
function autoDismissAlerts() {
  document.querySelectorAll(".alert").forEach(alert => {
    setTimeout(() => {
      alert.classList.remove("show")
      setTimeout(() => alert.remove(), 300)
    }, 4000)
  })
}

document.addEventListener("turbo:load", autoDismissAlerts)
document.addEventListener("turbo:render", autoDismissAlerts)

// Initialise Bootstrap tooltips
function initTooltips() {
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
    new bootstrap.Tooltip(el)
  })
}
document.addEventListener("turbo:load", initTooltips)

// Update bottom nav active state (nav is turbo-permanent so active class must be set via JS)
function updateBottomNavActive() {
  const nav = document.getElementById("customer-bottom-nav")
  if (!nav) return
  const path = window.location.pathname
  nav.querySelectorAll("a.bottom-nav-item[data-nav-path]").forEach(item => {
    item.classList.toggle("active", item.dataset.navPath === path)
  })
}

document.addEventListener("turbo:load", updateBottomNavActive)

// Close any open offcanvas (More drawer) before Turbo navigates
document.addEventListener("turbo:before-visit", () => {
  document.querySelectorAll(".offcanvas.show").forEach(el => {
    bootstrap.Offcanvas.getInstance(el)?.hide()
  })
})
