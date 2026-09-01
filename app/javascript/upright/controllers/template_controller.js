import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "body" ]

  fill({ params: { body } }) {
    this.bodyTarget.value = body
    this.bodyTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.bodyTarget.focus()
  }
}
