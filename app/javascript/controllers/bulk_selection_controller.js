import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "selectAll"]

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
    
    // Update select all checkbox state based on individual checkboxes
    if (this.hasSelectAllTarget) {
      const allChecked = this.checkboxTargets.length > 0 && 
                         this.checkboxTargets.every(cb => cb.checked)
      this.selectAllTarget.checked = allChecked
    }
  }

  clearSelection() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
    }
    this.updateCount()
  }
}
