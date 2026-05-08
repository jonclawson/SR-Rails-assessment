require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @product = products(:one)
    @order = Order.new(user: @user)
  end

  # Association tests
  test "should belong to user" do
    assert_respond_to @order, :user
    @order.user = nil
    assert_not @order.valid?
  end

  test "should have many line_items" do
    assert_respond_to @order, :line_items
    order = orders(:one)
    assert order.line_items.any?
  end

  test "should have many products through line_items" do
    assert_respond_to @order, :products
  end

  test "should have many order_transitions" do
    assert_respond_to @order, :order_transitions
  end

  test "should have many tracking_events" do
    assert_respond_to @order, :tracking_events
  end

  test "should destroy dependent line_items when order is destroyed" do
    order = orders(:one)
    line_item_count = order.line_items.count
    assert line_item_count > 0

    assert_difference "LineItem.count", -line_item_count do
      order.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    @order.line_items.build(product: @product, quantity: 1)
    assert @order.valid?
  end

  test "should require order_number" do
    @order.order_number = nil
    # Skip callback to test validation directly
    @order.define_singleton_method(:generate_order_number) { }
    assert_not @order.valid?
    assert_includes @order.errors[:order_number], "can't be blank"
  end

  test "should require unique order_number" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    duplicate_order = Order.new(user: @user, order_number: @order.order_number)
    duplicate_order.line_items.build(product: @product, quantity: 1)
    assert_not duplicate_order.valid?
    assert_includes duplicate_order.errors[:order_number], "has already been taken"
  end

  test "should require subtotal" do
    @order.define_singleton_method(:calculate_totals) { }
    @order.subtotal = nil
    assert_not @order.valid?
    assert_includes @order.errors[:subtotal], "can't be blank"
  end

  test "should require tax" do
    @order.define_singleton_method(:calculate_totals) { }
    @order.tax = nil
    assert_not @order.valid?
    assert_includes @order.errors[:tax], "can't be blank"
  end

  test "should require total" do
    @order.define_singleton_method(:calculate_totals) { }
    @order.total = nil
    assert_not @order.valid?
    assert_includes @order.errors[:total], "can't be blank"
  end

  test "should require subtotal to be non-negative" do
    @order.define_singleton_method(:calculate_totals) { }
    @order.subtotal = -1
    @order.tax = 0
    @order.total = 0
    assert_not @order.valid?
    assert_includes @order.errors[:subtotal], "must be greater than or equal to 0"
  end

  test "should require tax to be non-negative" do
    @order.define_singleton_method(:calculate_totals) { }
    @order.subtotal = 0
    @order.tax = -1
    @order.total = 0
    assert_not @order.valid?
    assert_includes @order.errors[:tax], "must be greater than or equal to 0"
  end

  test "should require total to be non-negative" do
    @order.define_singleton_method(:calculate_totals) { }
    @order.subtotal = 0
    @order.tax = 0
    @order.total = -1
    assert_not @order.valid?
    assert_includes @order.errors[:total], "must be greater than or equal to 0"
  end

  # Callback tests
  test "should automatically generate order_number on create" do
    @order.line_items.build(product: @product, quantity: 1)
    assert_nil @order.order_number
    @order.save!
    assert_not_nil @order.order_number
    assert_match /^ORD-[A-Z0-9]{10}$/, @order.order_number
  end

  test "should not override existing order_number" do
    custom_number = "CUSTOM-123"
    @order.order_number = custom_number
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!
    assert_equal custom_number, @order.order_number
  end

  test "should automatically calculate totals" do
    @order.line_items.build(product: @product, quantity: 2)
    @order.save!

    expected_subtotal = @product.price * 2
    expected_tax = (expected_subtotal * 0.08).round(2)
    expected_total = expected_subtotal + expected_tax

    assert_equal expected_subtotal, @order.subtotal
    assert_equal expected_tax, @order.tax
    assert_equal expected_total, @order.total
  end

  test "should recalculate totals when line items change" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    initial_total = @order.total

    @order.line_items.first.update!(quantity: 3)
    @order.reload
    @order.calculate_totals
    @order.save!

    assert_not_equal initial_total, @order.total
  end

  test "should handle multiple line items in total calculation" do
    product2 = products(:two)
    @order.line_items.build(product: @product, quantity: 2)
    @order.line_items.build(product: product2, quantity: 1)
    @order.save!

    expected_subtotal = (@product.price * 2) + (product2.price * 1)
    assert_equal expected_subtotal, @order.subtotal
  end

  test "should create initial transition after create" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    assert_equal 1, @order.order_transitions.count
    assert_equal "pending", @order.order_transitions.first.to_state
    assert @order.order_transitions.first.most_recent
  end

  # State machine tests
  test "should have pending as initial state" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!
    assert_equal "pending", @order.current_state
  end

  test "should transition from pending to approved" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    assert @order.can_transition_to?("approved")
    assert @order.transition_to!("approved")
    assert_equal "approved", @order.current_state
  end

  test "should transition from approved to shipped" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!
    @order.transition_to!("approved")

    assert @order.can_transition_to?("shipped")
    assert @order.transition_to!("shipped")
    assert_equal "shipped", @order.current_state
  end

  test "should transition from shipped to delivered" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!
    @order.transition_to!("approved")
    @order.transition_to!("shipped")

    assert @order.can_transition_to?("delivered")
    assert @order.transition_to!("delivered")
    assert_equal "delivered", @order.current_state
  end

  test "should allow canceling from pending" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    assert @order.can_transition_to?("canceled")
    assert @order.transition_to!("canceled")
    assert_equal "canceled", @order.current_state
  end

  test "should allow canceling from approved" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!
    @order.transition_to!("approved")

    assert @order.can_transition_to?("canceled")
    assert @order.transition_to!("canceled")
    assert_equal "canceled", @order.current_state
  end

  test "should not allow shipping without line items" do
    # Create order without line items
    order = Order.create!(user: @user, order_number: "TEST-NO-ITEMS")
    order.transition_to!("approved")

    assert_not order.can_transition_to?("shipped")
  end

  test "should not allow invalid state transitions" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    # Can't go directly from pending to shipped
    assert_not @order.can_transition_to?("shipped")
  end

  test "should check in_state? method" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    assert @order.in_state?(:pending)
    assert_not @order.in_state?(:approved)
  end

  test "should generate tracking number when transitioning to shipped" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!
    @order.transition_to!("approved")

    assert_nil @order.tracking_number
    @order.transition_to!("shipped")
    @order.reload

    assert_not_nil @order.tracking_number
    assert_match /^TRK[A-Z0-9]{12}$/, @order.tracking_number
  end

  test "should not override existing tracking number when transitioning to shipped" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.tracking_number = "CUSTOM-TRACKING"
    @order.save!
    @order.transition_to!("approved")
    @order.transition_to!("shipped")
    @order.reload

    assert_equal "CUSTOM-TRACKING", @order.tracking_number
  end

  # Scope tests
  test "recent scope should order by created_at desc" do
    old_order = Order.create!(user: @user, order_number: "OLD-ORDER")
    old_order.update_column(:created_at, 2.days.ago)

    new_order = Order.create!(user: @user, order_number: "NEW-ORDER")

    recent_orders = Order.recent.limit(2)
    assert_equal new_order.id, recent_orders.first.id
  end

  test "search scope should find orders by order number" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.order_number = "SEARCH-TEST-123"
    @order.save!

    results = Order.search("SEARCH-TEST")
    assert_includes results, @order

    results = Order.search("NOMATCH")
    assert_not_includes results, @order
  end

  test "search scope should be case insensitive" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.order_number = "ABC-123"
    @order.save!

    assert_includes Order.search("abc"), @order
    assert_includes Order.search("ABC"), @order
  end

  # Helper method tests
  test "formatted_total should return currency formatted string" do
    @order.total = 123.45
    assert_equal "$123.45", @order.formatted_total

    @order.total = 99.99
    assert_equal "$99.99", @order.formatted_total
  end

  # Nested attributes tests
  test "should accept nested attributes for line items" do
    order_params = {
      user: @user,
      line_items_attributes: {
        "0" => { product_id: @product.id, quantity: 2 },
        "1" => { product_id: products(:two).id, quantity: 1 }
      }
    }

    order = Order.create!(order_params)
    assert_equal 2, order.line_items.count
  end

  test "should allow destroying line items through nested attributes" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    line_item_id = @order.line_items.first.id

    @order.update!(
      line_items_attributes: {
        "0" => { id: line_item_id, _destroy: "1" }
      }
    )

    assert_equal 0, @order.line_items.count
  end

  test "should reject blank nested line items" do
    order_params = {
      user: @user,
      line_items_attributes: {
        "0" => { product_id: @product.id, quantity: 2 },
        "1" => { product_id: nil, quantity: nil }
      }
    }

    order = Order.create!(order_params)
    assert_equal 1, order.line_items.count
  end

  # PaperTrail auditing test
  test "should track changes with paper_trail" do
    @order.line_items.build(product: @product, quantity: 1)
    @order.save!

    assert_respond_to @order, :versions
    initial_version_count = @order.versions.count

    @order.update!(tracking_number: "TRACK-123")
    assert_equal initial_version_count + 1, @order.versions.count
  end

  # Integration tests
  test "should create complete order with line items and calculate totals" do
    order = Order.create!(
      user: @user,
      line_items_attributes: {
        "0" => { product_id: @product.id, quantity: 3 }
      }
    )

    assert order.persisted?
    assert_not_nil order.order_number
    assert_equal 1, order.line_items.count
    assert order.subtotal > 0
    assert order.tax > 0
    assert order.total > 0
    assert_equal "pending", order.current_state
  end
end
