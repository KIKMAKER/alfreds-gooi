import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";
import { put } from "@rails/request.js";

// Connects to data-controller="sortable"
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = new Sortable(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",  // Optional styling for the dragged item
      onEnd: this.onEnd.bind(this),  // Trigger this method when the sorting ends
    })
  }

  disconnect() {
    this.sortable.destroy()
  }

  onEnd(event) {
    const { newIndex, item } = event

    // Get the URL to update the collection position
    const url = item.dataset.sortableUrl

    // Send the new position to the backend using PUT request
    put(url, {
      body: JSON.stringify({ position: newIndex + 1 })  // `+1` to adjust to 1-based index
    })
      .then(response => console.log("Position updated", response))
      .catch(error => console.error("Error updating position", error))
  }
}
