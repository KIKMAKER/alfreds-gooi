// import { Controller } from "@hotwired/stimulus"

// export default class extends Controller {
//   static targets = ["select", "result"]

//   connect() {
//     this.tuesday = <%= raw Subscription::TUESDAY_SUBURBS.to_json %>
//     this.wednesday = <%= raw Subscription::WEDNESDAY_SUBURBS.to_json %>
//     this.thursday = <%= raw Subscription::THURSDAY_SUBURBS.to_json %>
//   }

//   check() {
//     const suburb = this.selectTarget.value
//     let message = ""

//     if (this.tuesday.includes(suburb)) {
//       message = `✅ Yes! We collect in ${suburb} on Tuesdays.`
//     } else if (this.wednesday.includes(suburb)) {
//       message = `✅ Yes! We collect in ${suburb} on Wednesdays.`
//     } else if (this.thursday.includes(suburb)) {
//       message = `✅ Yes! We collect in ${suburb} on Thursdays.`
//     } else {
//       message = `❌ Not yet — but let us know you’re keen!`
//     }

//     this.resultTarget.textContent = message
//   }
// }
