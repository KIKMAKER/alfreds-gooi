import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";
import { put } from "@rails/request.js";

// Connects to data-controller="sortable"
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = new Sortable(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",
      draggable: ".sortable-item",
      handle: ".drag-handle",
      delay: 200,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      onEnd: this.onEnd.bind(this),
    })
  }

  disconnect() {
    this.sortable.destroy()
  }

  onEnd() {
    const items = Array.from(this.element.querySelectorAll(".sortable-item"))
      .map(el => ({
        type: el.dataset.sortableType,
        id:   el.dataset.sortableId,
      }))

    put(this.urlValue, {
      body: JSON.stringify({ items }),
      headers: { "Content-Type": "application/json" },
    })
  }
}
