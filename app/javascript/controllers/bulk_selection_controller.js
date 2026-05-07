import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "selectAll", "bulkBar", "selectAllBanner"]
  static values = { totalCount: Number }

  connect() {
    // Load selections from localStorage
    this.loadSelectionsFromStorage()
    this.updateCount()
  }

  loadSelectionsFromStorage() {
    const selectAllMode = localStorage.getItem('select_all_mode') === 'true'
    const selectedIds = JSON.parse(localStorage.getItem('selected_order_ids') || '[]')
    
    if (selectAllMode) {
      // Check all boxes if in select-all mode
      this.checkboxTargets.forEach(checkbox => {
        checkbox.checked = true
      })
      if (this.hasSelectAllTarget) {
        this.selectAllTarget.checked = true
      }
    } else {
      // Check boxes based on stored IDs
      this.checkboxTargets.forEach(checkbox => {
        const orderId = parseInt(checkbox.value)
        if (selectedIds.includes(orderId)) {
          checkbox.checked = true
        }
      })
      
      // Update select all checkbox state
      if (this.hasSelectAllTarget) {
        const allChecked = this.checkboxTargets.length > 0 && 
                           this.checkboxTargets.every(cb => cb.checked)
        this.selectAllTarget.checked = allChecked
      }
    }
  }

  toggleCheckbox(event) {
    const checkbox = event.target
    const orderId = parseInt(checkbox.value)
    const checked = checkbox.checked
    
    // Update localStorage
    let selectedIds = JSON.parse(localStorage.getItem('selected_order_ids') || '[]')
    
    if (checked) {
      if (!selectedIds.includes(orderId)) {
        selectedIds.push(orderId)
      }
    } else {
      selectedIds = selectedIds.filter(id => id !== orderId)
      // If user unchecks something, exit select-all mode
      localStorage.removeItem('select_all_mode')
    }
    
    localStorage.setItem('selected_order_ids', JSON.stringify(selectedIds))
    this.updateCount()
  }

  toggleAll(event) {
    const checked = event.target.checked
    
    // Get current selections
    let selectedIds = JSON.parse(localStorage.getItem('selected_order_ids') || '[]')
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
      const orderId = parseInt(checkbox.value)
      
      if (checked) {
        if (!selectedIds.includes(orderId)) {
          selectedIds.push(orderId)
        }
      } else {
        selectedIds = selectedIds.filter(id => id !== orderId)
      }
    })
    
    localStorage.setItem('selected_order_ids', JSON.stringify(selectedIds))
    localStorage.removeItem('select_all_mode')
    
    this.updateCount()
  }

  updateCount() {
    const selectAllMode = localStorage.getItem('select_all_mode') === 'true'
    const selectedIds = JSON.parse(localStorage.getItem('selected_order_ids') || '[]')
    
    // Update count display
    if (selectAllMode) {
      this.countTarget.textContent = `All ${this.totalCountValue}`
    } else {
      this.countTarget.textContent = selectedIds.length
    }
    
    // Show/hide bulk actions bar
    if (this.hasBulkBarTarget) {
      if (selectedIds.length > 0 || selectAllMode) {
        this.bulkBarTarget.classList.remove("hidden")
      } else {
        this.bulkBarTarget.classList.add("hidden")
      }
    }
    
    // Show "select all matching" banner if all on page are selected but not in select-all mode
    if (this.hasSelectAllBannerTarget) {
      const allChecked = this.checkboxTargets.length > 0 && 
                         this.checkboxTargets.every(cb => cb.checked)
      
      if (allChecked && !selectAllMode && this.totalCountValue > this.checkboxTargets.length) {
        this.selectAllBannerTarget.classList.remove("hidden")
      } else {
        this.selectAllBannerTarget.classList.add("hidden")
      }
    }
    
    // Update select all checkbox state based on individual checkboxes (only if not in select-all mode)
    if (this.hasSelectAllTarget && !selectAllMode) {
      const allChecked = this.checkboxTargets.length > 0 && 
                         this.checkboxTargets.every(cb => cb.checked)
      this.selectAllTarget.checked = allChecked
    }
  }

  selectAllMatching() {
    // Enable select-all mode in localStorage
    localStorage.setItem('select_all_mode', 'true')
    
    // Store current filters for reference
    const url = new URL(window.location)
    localStorage.setItem('select_all_filters', JSON.stringify({
      state: url.searchParams.get('state'),
      search: url.searchParams.get('search')
    }))
    
    // Check all visible checkboxes
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = true
    }
    
    this.updateCount()
  }

  clearSelection() {
    // Clear localStorage
    localStorage.removeItem('selected_order_ids')
    localStorage.removeItem('select_all_mode')
    localStorage.removeItem('select_all_filters')
    
    // Uncheck all boxes
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
    }
    
    this.updateCount()
  }

  handleSubmit(event) {
    const form = event.target
    const selectAllMode = localStorage.getItem('select_all_mode') === 'true'
    
    if (selectAllMode) {
      // Remove existing order_ids[] inputs
      form.querySelectorAll('input[name="order_ids[]"]').forEach(input => input.remove())
      
      // Add hidden input for select_all_mode
      const selectAllInput = document.createElement('input')
      selectAllInput.type = 'hidden'
      selectAllInput.name = 'select_all_mode'
      selectAllInput.value = 'true'
      form.appendChild(selectAllInput)
      
      // Add filters so server knows which orders to select
      const filters = JSON.parse(localStorage.getItem('select_all_filters') || '{}')
      if (filters.state) {
        const stateInput = document.createElement('input')
        stateInput.type = 'hidden'
        stateInput.name = 'state'
        stateInput.value = filters.state
        form.appendChild(stateInput)
      }
      if (filters.search) {
        const searchInput = document.createElement('input')
        searchInput.type = 'hidden'
        searchInput.name = 'search'
        searchInput.value = filters.search
        form.appendChild(searchInput)
      }
      
      // Clear localStorage after submission
      setTimeout(() => {
        localStorage.removeItem('selected_order_ids')
        localStorage.removeItem('select_all_mode')
        localStorage.removeItem('select_all_filters')
      }, 100)
    } else {
      // Use stored IDs instead of just checked boxes
      const selectedIds = JSON.parse(localStorage.getItem('selected_order_ids') || '[]')
      
      if (selectedIds.length === 0) {
        event.preventDefault()
        alert('No orders selected')
        return
      }
      
      // Remove existing checkboxes from form
      form.querySelectorAll('input[name="order_ids[]"]').forEach(input => input.remove())
      
      // Add hidden inputs for all selected IDs from localStorage
      selectedIds.forEach(orderId => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = 'order_ids[]'
        input.value = orderId
        form.appendChild(input)
      })
      
      // Clear localStorage after submission
      setTimeout(() => {
        localStorage.removeItem('selected_order_ids')
        localStorage.removeItem('select_all_mode')
        localStorage.removeItem('select_all_filters')
      }, 100)
    }
  }
}
