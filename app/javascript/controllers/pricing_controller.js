import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title"]

  connect() {
    console.log("Hello, Stimulus!", this.element)
  }

  toggle() {
    console.log("I'm toggling!")
    if(this.titleTarget.innerText === "Standard") {
    this.titleTarget.innerText = "Extra large";
  } else {
    this.titleTarget.innerText = "Standard";
  }

}
}
