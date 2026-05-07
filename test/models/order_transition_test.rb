require "test_helper"

class OrderTransitionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @product = products(:one)
    @order = Order.create!(
      user: @user,
      line_items_attributes: {
        "0" => { product_id: @product.id, quantity: 1 }
      }
    )
  end

  # Association tests
  test "should belong to order" do
    transition = @order.order_transitions.first
    assert_respond_to transition, :order
    assert_equal @order, transition.order
  end

  test "should have inverse relationship with order" do
    transition = @order.order_transitions.first
    assert_includes @order.order_transitions, transition
  end

  # Attribute tests
  test "should have required attributes" do
    transition = @order.order_transitions.first
    assert_not_nil transition.to_state
    assert_not_nil transition.sort_key
    assert_not_nil transition.most_recent
    assert_not_nil transition.metadata
  end

  test "should store to_state as string" do
    transition = @order.order_transitions.first
    assert_equal "pending", transition.to_state
    assert_kind_of String, transition.to_state
  end

  test "should store metadata as hash" do
    @order.transition_to!("approved", user_id: @user.id, reason: "test")
    transition = @order.order_transitions.order(:sort_key).last

    assert_kind_of Hash, transition.metadata
    assert_equal @user.id, transition.metadata["user_id"]
    assert_equal "test", transition.metadata["reason"]
  end

  test "should default metadata to empty hash" do
    transition = @order.order_transitions.first
    assert_equal({}, transition.metadata)
  end

  test "should track most_recent flag" do
    initial_transition = @order.order_transitions.first
    assert initial_transition.most_recent

    @order.transition_to!("approved")
    initial_transition.reload

    assert_not initial_transition.most_recent
    assert @order.order_transitions.order(:sort_key).last.most_recent
  end

  test "should have unique sort_key per order" do
    transitions = @order.order_transitions.order(:sort_key)
    assert_equal 1, transitions.count

    @order.transition_to!("approved")
    @order.transition_to!("shipped")

    transitions = @order.order_transitions.order(:sort_key)
    assert_equal 3, transitions.count

    sort_keys = transitions.pluck(:sort_key)
    assert_equal sort_keys.uniq, sort_keys, "Sort keys should be unique"
  end

  # Callback tests
  test "should update most_recent on destroy" do
    @order.transition_to!("approved")
    @order.transition_to!("shipped")

    # Get the most recent transition
    most_recent = @order.order_transitions.where(most_recent: true).first
    assert_equal "shipped", most_recent.to_state

    # Destroy it
    most_recent.destroy

    # The previous transition should now be most_recent
    new_most_recent = @order.order_transitions.where(most_recent: true).first
    assert_equal "approved", new_most_recent.to_state
  end

  test "should handle destroy when it is the only transition" do
    # Get initial transition
    transition = @order.order_transitions.first
    assert_equal 1, @order.order_transitions.count

    # Destroying the only transition should not raise error
    assert_nothing_raised do
      transition.destroy
    end

    assert_equal 0, @order.order_transitions.count
  end

  test "should only trigger callback if transition was most_recent" do
    @order.transition_to!("approved")
    @order.transition_to!("shipped")

    # Get the first (not most recent) transition
    old_transition = @order.order_transitions.order(:sort_key).first
    assert_not old_transition.most_recent

    most_recent_before = @order.order_transitions.where(most_recent: true).first

    # Destroy the old transition
    old_transition.destroy

    # Most recent should not have changed
    most_recent_after = @order.order_transitions.where(most_recent: true).first
    assert_equal most_recent_before.id, most_recent_after.id
  end

  # State tracking tests
  test "should correctly track state history" do
    assert_equal 1, @order.order_transitions.count

    @order.transition_to!("approved")
    assert_equal 2, @order.order_transitions.count

    @order.transition_to!("shipped")
    assert_equal 3, @order.order_transitions.count

    states = @order.order_transitions.order(:sort_key).pluck(:to_state)
    assert_equal [ "pending", "approved", "shipped" ], states
  end

  test "should maintain chronological order via sort_key" do
    @order.transition_to!("approved")
    sleep 0.01 # Ensure different timestamps
    @order.transition_to!("shipped")

    transitions = @order.order_transitions.order(:sort_key)
    sort_keys = transitions.pluck(:sort_key)

    assert_equal sort_keys, sort_keys.sort, "Sort keys should be in ascending order"
  end

  # Integration tests with Statesman
  test "should work with statesman state machine" do
    # Initial state
    assert_equal "pending", @order.current_state
    assert_equal 1, @order.order_transitions.count

    # Transition to approved
    @order.transition_to!("approved")
    assert_equal "approved", @order.current_state
    assert_equal 2, @order.order_transitions.count

    # Most recent should be the approved transition
    most_recent = @order.order_transitions.where(most_recent: true).first
    assert_equal "approved", most_recent.to_state
  end

  test "should store metadata with transitions" do
    metadata = {
      user_id: @user.id,
      reason: "Approved by staff",
      ip_address: "192.168.1.1"
    }

    @order.transition_to!("approved", metadata)

    transition = @order.order_transitions.order(:sort_key).last
    assert_equal @user.id, transition.metadata["user_id"]
    assert_equal "Approved by staff", transition.metadata["reason"]
    assert_equal "192.168.1.1", transition.metadata["ip_address"]
  end

  test "should handle complex metadata structures" do
    complex_metadata = {
      user: { id: @user.id, email: @user.email_address },
      changes: [ "status", "tracking" ],
      timestamp: Time.current.iso8601,
      nested: { deep: { value: 123 } }
    }

    @order.transition_to!("approved", complex_metadata)

    transition = @order.order_transitions.order(:sort_key).last
    assert_equal @user.id, transition.metadata["user"]["id"]
    assert_equal @user.email_address, transition.metadata["user"]["email"]
    assert_equal [ "status", "tracking" ], transition.metadata["changes"]
    assert_equal 123, transition.metadata["nested"]["deep"]["value"]
  end

  # Index constraint tests
  test "should enforce unique sort_key per order" do
    transition = @order.order_transitions.first

    duplicate = OrderTransition.new(
      order: @order,
      to_state: "approved",
      sort_key: transition.sort_key,
      most_recent: false
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end

  test "should enforce only one most_recent per order" do
    # Create a second order
    order2 = Order.create!(
      user: @user,
      line_items_attributes: {
        "0" => { product_id: @product.id, quantity: 1 }
      }
    )

    # Each order should have one most_recent transition
    assert_equal 1, @order.order_transitions.where(most_recent: true).count
    assert_equal 1, order2.order_transitions.where(most_recent: true).count

    # Try to create another most_recent for the same order
    duplicate_most_recent = OrderTransition.new(
      order: @order,
      to_state: "approved",
      sort_key: 999,
      most_recent: true
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate_most_recent.save!(validate: false)
    end
  end

  test "should allow multiple orders to have most_recent transitions" do
    order2 = Order.create!(
      user: @user,
      line_items_attributes: {
        "0" => { product_id: @product.id, quantity: 1 }
      }
    )

    # Both orders should have a most_recent transition
    assert @order.order_transitions.where(most_recent: true).exists?
    assert order2.order_transitions.where(most_recent: true).exists?
  end

  # Edge case tests
  test "should handle empty metadata" do
    @order.transition_to!("approved", {})
    transition = @order.order_transitions.order(:sort_key).last
    assert_equal({}, transition.metadata)
  end

  test "should handle nil metadata" do
    @order.transition_to!("approved", nil)
    transition = @order.order_transitions.order(:sort_key).last
    # Statesman may store nil or empty hash depending on implementation
    assert transition.metadata.nil? || transition.metadata == {}
  end

  test "should preserve metadata types" do
    metadata = {
      integer: 42,
      float: 3.14,
      boolean: true,
      null: nil,
      array: [ 1, 2, 3 ],
      hash: { key: "value" }
    }

    @order.transition_to!("approved", metadata)
    transition = @order.order_transitions.order(:sort_key).last

    assert_equal 42, transition.metadata["integer"]
    assert_equal 3.14, transition.metadata["float"]
    assert_equal true, transition.metadata["boolean"]
    assert_nil transition.metadata["null"]
    assert_equal [ 1, 2, 3 ], transition.metadata["array"]
    assert_equal({ "key" => "value" }, transition.metadata["hash"])
  end
end
