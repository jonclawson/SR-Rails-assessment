import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count"]

  connect() {
    this.updateCount()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateCount()
  }

  updateCount() {
    const count = this.checkboxTargets.filter(cb => cb.checked).length
    this.countTarget.textContent = count
  }

  clearSelection() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateCount()
  }
}
