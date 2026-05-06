require 'rails_helper'

RSpec.describe "Bulk Order Approval", type: :system do
  # This system spec tests the critical path of a staff member logging in
  # and using the bulk actions feature to approve multiple pending orders at once.

  let!(:staff_user) { User.create!(email_address: "staff@test.com", password: "password123") }
  let!(:product) { Product.create!(name: "Widget", sku: "WDG-001", price: 29.99, description: "A test widget") }

  # Create three pending orders for bulk approval
  let!(:order1) do
    Order.create!(user: staff_user).tap do |order|
      order.line_items.create!(product: product, quantity: 2)
      order.calculate_totals
      order.save!
    end
  end

  let!(:order2) do
    Order.create!(user: staff_user).tap do |order|
      order.line_items.create!(product: product, quantity: 1)
      order.calculate_totals
      order.save!
    end
  end

  let!(:order3) do
    Order.create!(user: staff_user).tap do |order|
      order.line_items.create!(product: product, quantity: 3)
      order.calculate_totals
      order.save!
    end
  end

  # Create an additional order to verify selective bulk operations
  let!(:order_not_selected) do
    Order.create!(user: staff_user).tap do |order|
      order.line_items.create!(product: product, quantity: 1)
      order.calculate_totals
      order.save!
    end
  end

  before do
    # Ensure all orders start in pending state
    expect(order1.current_state).to eq("pending")
    expect(order2.current_state).to eq("pending")
    expect(order3.current_state).to eq("pending")
    expect(order_not_selected.current_state).to eq("pending")
  end

  scenario "Staff member logs in and bulk-approves three pending orders" do
    # Step 1: Visit the login page
    visit root_path

    # Verify we're on the login page
    expect(page).to have_content("Sign in")
    expect(page).to have_field("email_address")
    expect(page).to have_field("password")

    # Step 2: Fill in credentials and sign in
    fill_in "email_address", with: "staff@test.com"
    fill_in "password", with: "password123"
    click_button "Sign in"

    # Step 3: Verify successful login - should be on orders dashboard
    expect(page).to have_content("Orders Dashboard")
    expect(page).to have_content("Manage and track customer orders")

    # Step 4: Verify all four orders are visible
    expect(page).to have_content(order1.order_number)
    expect(page).to have_content(order2.order_number)
    expect(page).to have_content(order3.order_number)
    expect(page).to have_content(order_not_selected.order_number)

    # Step 5: Verify bulk actions form is initially hidden
    expect(page).not_to have_content("order(s) selected")
    bulk_form = find("#bulk-actions-form", visible: :all)
    expect(bulk_form[:class]).to include("hidden")

    # Step 6: Select three specific orders (not the fourth one)
    # Find checkboxes by value (order IDs)
    checkboxes = all("input[name='order_ids[]']")

  # Select first three orders
  checkboxes[0].check

    # After first selection, bulk actions should become visible
    # Wait for JavaScript to show the form
    expect(page).to have_css("#bulk-actions-form:not(.hidden)", wait: 5)
    expect(page).to have_content("1 order(s) selected")

    # Select second order
    checkboxes[1].check
    expect(page).to have_content("2 order(s) selected", wait: 2)

    # Select third order
    checkboxes[2].check
    expect(page).to have_content("3 order(s) selected", wait: 2)

    # Verify fourth order is NOT selected (checkbox unchecked)
    expect(checkboxes[3]).not_to be_checked

    # Step 7: Select "Approved" from the state transition dropdown
    within "#bulk-actions-form" do
      select "Approved", from: "to_state"
    end

    # Step 8: Click Apply to perform bulk transition
    within "#bulk-actions-form" do
      click_button "Apply"
    end

    # Step 9: Verify success message
    expect(page).to have_content("Successfully transitioned 3 order(s)")

    # Step 10: Verify the three selected orders are now in "approved" state
    order1.reload
    order2.reload
    order3.reload
    order_not_selected.reload

    expect(order1.current_state).to eq("approved")
    expect(order2.current_state).to eq("approved")
    expect(order3.current_state).to eq("approved")

    # Step 11: Verify the unselected order is still "pending"
    expect(order_not_selected.current_state).to eq("pending")

    # Step 12: Filter by "Approved" state tab to see only approved orders
    click_link "approved", match: :first

    # Should see the three approved orders
    expect(page).to have_content(order1.order_number)
    expect(page).to have_content(order2.order_number)
    expect(page).to have_content(order3.order_number)

    # Should NOT see the still-pending order
    expect(page).not_to have_content(order_not_selected.order_number)

    # Step 13: Verify state badges reflect approved status
    within "tr", text: order1.order_number do
      expect(page).to have_css(".bg-blue-100", text: "approved")
    end

    # Step 14: Click on one of the approved orders to view details
    click_link order1.order_number

    # Step 15: Verify order detail page shows approved state
    expect(page).to have_content(order1.order_number)
    expect(page).to have_css(".bg-blue-100", text: "approved")

    # Step 16: Verify state transition history shows pending -> approved
    expect(page).to have_content("State History")
    within ".bg-white.shadow", text: "State History" do
      expect(page).to have_content("approved")
      expect(page).to have_content("pending")
    end

    # Step 17: Verify audit trail records the staff member who made the change
    expect(page).to have_content("Audit Trail")
    within ".bg-white.shadow", text: "Audit Trail" do
      expect(page).to have_content("Update")
      expect(page).to have_content("staff@test.com")
    end
  end

  scenario "Bulk actions form visibility toggles correctly" do
    sign_in_as(staff_user)

    # Initially hidden
    expect(page).to have_css("#bulk-actions-form.hidden", visible: :all)

    # Check one order - form appears
    first("input[name='order_ids[]']").check
    expect(page).to have_css("#bulk-actions-form:not(.hidden)", wait: 5)
    expect(page).to have_content("1 order(s) selected")

    # Clear selection - form hides again
    click_button "Clear selection"
    expect(page).to have_css("#bulk-actions-form.hidden", visible: :all, wait: 2)
  end

  scenario "Select all checkbox selects all visible orders" do
    sign_in_as(staff_user)

    # Use select-all checkbox
    check "select-all"

    # Wait for JavaScript to process and show bulk form
    expect(page).to have_css("#bulk-actions-form:not(.hidden)", wait: 5)

    # All four orders should be selected
    expect(page).to have_content("4 order(s) selected")

    # Verify all checkboxes are checked
    all("input[name='order_ids[]']").each do |checkbox|
      expect(checkbox).to be_checked
    end

    # Uncheck select-all
    uncheck "select-all"

    # Form should hide again
    expect(page).to have_css("#bulk-actions-form.hidden", visible: :all, wait: 2)
  end

  scenario "Bulk transition fails gracefully for invalid state" do
    sign_in_as(staff_user)

    # Select an order
    first("input[name='order_ids[]']").check

    # Wait for bulk form to appear
    expect(page).to have_css("#bulk-actions-form:not(.hidden)", wait: 5)

    # Try to transition without selecting a state (leave dropdown at default)
    within "#bulk-actions-form" do
      click_button "Apply"
    end

    # Should show error message
    expect(page).to have_content("Invalid state")
  end

  scenario "Audit trail captures bulk operation user" do
    sign_in_as(staff_user)

    # Select and approve orders
    first("input[name='order_ids[]']").check

    # Wait for bulk form to appear
    expect(page).to have_css("#bulk-actions-form:not(.hidden)", wait: 5)

    # Select approved state
    within "#bulk-actions-form" do
      select "Approved", from: "to_state"
      click_button "Apply"
    end

    # Wait for success message
    expect(page).to have_content("Successfully transitioned")

    # Check the order's versions
    order1.reload
    last_version = order1.versions.last

    expect(last_version.whodunnit).to eq(staff_user.id.to_s)
  end
end
