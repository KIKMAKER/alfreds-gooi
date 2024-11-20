import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "icon" ]

  toggleHide() {
    this.menuTarget.classList.toggle("hide");
    const icon =  this.iconTarget;
    const currentSrc = icon.getAttribute("src");
    console.log(icon);
    if(currentSrc === "menu-svgrepo-com.png") {
      icon.setAttribute("close-md-svgrepo-com.png");
    } else {
      icon.setAttribute("menu-svgrepo-com.png");
    }
  }

}
