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

    # Step 5: Verify bulk actions form is visible
    expect(page).to have_css("#bulk-actions-form")
    expect(page).to have_content("order(s) selected")

    # Step 6: Select three specific orders by their IDs (not the fourth one)
    # Note: Orders are displayed newest first, so we need to select by value
    find("input[name='order_ids[]'][value='#{order1.id}']").check
    find("input[name='order_ids[]'][value='#{order2.id}']").check
    find("input[name='order_ids[]'][value='#{order3.id}']").check

    # Verify the fourth order is NOT selected
    fourth_checkbox = find("input[name='order_ids[]'][value='#{order_not_selected.id}']")
    expect(fourth_checkbox).not_to be_checked

    # Step 7: Select "Approved" from the state transition dropdown
    within "#bulk-actions-form" do
      select "Approved", from: "to_state"
    end

    # Step 8: Click Apply to perform bulk transition
    within "#bulk-actions-form" do
      click_button "Apply"
    end

    # # Step 9: Verify success message
    expect(page).to have_content("Successfully transitioned 3 order(s) to approved")

    # # Step 10: Verify the three selected orders are now in "approved" state
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
    expect(page).to have_css(".bg-blue-100", text: "Approved")

    # Step 16: Verify state transition history shows pending -> approved
    expect(page).to have_content("State History")
    within ".bg-white.shadow", text: "State History" do
      expect(page).to have_content("Approved")
      expect(page).to have_content("Pending")
    end

    # # Step 17: Verify audit trail records the staff member who made the change
    # expect(page).to have_content("Audit Trail")
    # within ".bg-white.shadow", text: "Audit Trail" do
    #   expect(page).to have_content("Update")
    #   expect(page).to have_content("staff@test.com")
    # end
  end

  scenario "Bulk actions form is always visible" do
    sign_in_as(staff_user)

    # Form should be visible with default count
    expect(page).to have_css("#bulk-actions-form")
    expect(page).to have_content("order(s) selected")
  end

  scenario "Multiple orders can be selected" do
    sign_in_as(staff_user)

    # Select specific orders by their IDs
    find("input[name='order_ids[]'][value='#{order1.id}']").check
    find("input[name='order_ids[]'][value='#{order2.id}']").check
    find("input[name='order_ids[]'][value='#{order3.id}']").check

    # Verify specific checkboxes are checked
    expect(find("input[name='order_ids[]'][value='#{order1.id}']")).to be_checked
    expect(find("input[name='order_ids[]'][value='#{order2.id}']")).to be_checked
    expect(find("input[name='order_ids[]'][value='#{order3.id}']")).to be_checked
    expect(find("input[name='order_ids[]'][value='#{order_not_selected.id}']")).not_to be_checked
  end

  scenario "Bulk transition fails gracefully for invalid state" do
    sign_in_as(staff_user)

    # Select an order
    first("input[name='order_ids[]']").check

    # Try to transition without selecting a state (leave dropdown at default)
    within "#bulk-actions-form" do
      click_button "Apply"
    end

    # Should show error message
    expect(page).to have_content("Invalid state")
  end

  scenario "Audit trail captures bulk operation user" do
    sign_in_as(staff_user)

    # Select order1 specifically
    find("input[name='order_ids[]'][value='#{order1.id}']").check

    # Select approved state
    within "#bulk-actions-form" do
      select "Approved", from: "to_state"
      click_button "Apply"
    end

    # Wait for success message
    expect(page).to have_content("Successfully transitioned")

    # Check order1's versions
    order1.reload
    last_version = order1.versions.last

    expect(last_version.whodunnit).to eq(staff_user.id.to_s)
  end
end
