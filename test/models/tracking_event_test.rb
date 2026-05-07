require "test_helper"

class TrackingEventTest < ActiveSupport::TestCase
  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    @tracking_event = tracking_events(:one)
  end

  # ============================================================================
  # Basic Validations
  # ============================================================================

  test "valid tracking event" do
    assert @tracking_event.valid?
  end

  test "invalid without carrier" do
    @tracking_event.carrier = nil
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:carrier], "can't be blank"
  end

  test "invalid without tracking_number" do
    @tracking_event.tracking_number = nil
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:tracking_number], "can't be blank"
  end

  test "invalid without event_type" do
    @tracking_event.event_type = nil
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:event_type], "can't be blank"
  end

  test "invalid without occurred_at" do
    @tracking_event.occurred_at = nil
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:occurred_at], "can't be blank"
  end

  test "valid with blank carrier gives validation error" do
    @tracking_event.carrier = ""
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:carrier], "can't be blank"
  end

  test "valid with blank tracking_number gives validation error" do
    @tracking_event.tracking_number = ""
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:tracking_number], "can't be blank"
  end

  test "valid with blank event_type gives validation error" do
    @tracking_event.event_type = ""
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:event_type], "can't be blank"
  end

  # ============================================================================
  # Optional Fields
  # ============================================================================

  test "description is optional" do
    @tracking_event.description = nil
    assert @tracking_event.valid?
  end

  test "location is optional" do
    @tracking_event.location = nil
    assert @tracking_event.valid?
  end

  # ============================================================================
  # Associations
  # ============================================================================

  test "belongs to order" do
    assert_respond_to @tracking_event, :order
  end

  test "association returns correct order" do
    assert_equal orders(:one), @tracking_event.order
  end

  test "invalid without order" do
    @tracking_event.order = nil
    refute @tracking_event.valid?
    assert_includes @tracking_event.errors[:order], "must exist"
  end

  test "order association is required" do
    tracking_event = TrackingEvent.new(
      carrier: "USPS",
      tracking_number: "123456789",
      event_type: "shipped",
      occurred_at: Time.current
    )
    refute tracking_event.valid?
    assert_includes tracking_event.errors[:order], "must exist"
  end

  # ============================================================================
  # Scopes
  # ============================================================================

  test "recent_first scope orders by occurred_at descending" do
    # Create events with different timestamps
    oldest = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: "OLD123",
      event_type: "shipped",
      occurred_at: 3.days.ago
    )

    newest = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: "NEW123",
      event_type: "delivered",
      occurred_at: 1.day.ago
    )

    middle = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: "MID123",
      event_type: "in_transit",
      occurred_at: 2.days.ago
    )

    events = TrackingEvent.recent_first.where(tracking_number: [ "OLD123", "NEW123", "MID123" ])
    assert_equal [ newest, middle, oldest ], events.to_a
  end

  test "for_tracking_number scope filters by tracking number" do
    event1 = TrackingEvent.create!(
      order: orders(:one),
      carrier: "UPS",
      tracking_number: "TRACK001",
      event_type: "shipped",
      occurred_at: Time.current
    )

    event2 = TrackingEvent.create!(
      order: orders(:one),
      carrier: "UPS",
      tracking_number: "TRACK001",
      event_type: "in_transit",
      occurred_at: Time.current
    )

    event3 = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: "TRACK002",
      event_type: "delivered",
      occurred_at: Time.current
    )

    events = TrackingEvent.for_tracking_number("TRACK001")
    assert_includes events, event1
    assert_includes events, event2
    refute_includes events, event3
  end

  test "for_tracking_number scope returns empty when no matches" do
    events = TrackingEvent.for_tracking_number("NONEXISTENT")
    assert_empty events
  end

  # ============================================================================
  # Event Types
  # ============================================================================

  test "accepts various event types" do
    event_types = [ "shipped", "in_transit", "out_for_delivery", "delivered", "exception", "attempted_delivery" ]

    event_types.each do |type|
      tracking_event = TrackingEvent.new(
        order: orders(:one),
        carrier: "FedEx",
        tracking_number: "TEST#{type}",
        event_type: type,
        occurred_at: Time.current
      )
      assert tracking_event.valid?, "Expected #{type} to be valid"
    end
  end

  # ============================================================================
  # Carrier Support
  # ============================================================================

  test "accepts various carriers" do
    carriers = [ "FedEx", "UPS", "USPS", "DHL", "OnTrac", "Amazon Logistics" ]

    carriers.each do |carrier|
      tracking_event = TrackingEvent.new(
        order: orders(:one),
        carrier: carrier,
        tracking_number: "TEST#{carrier}",
        event_type: "shipped",
        occurred_at: Time.current
      )
      assert tracking_event.valid?, "Expected #{carrier} to be valid"
    end
  end

  # ============================================================================
  # Timestamp Handling
  # ============================================================================

  test "occurred_at can be in the past" do
    @tracking_event.occurred_at = 1.year.ago
    assert @tracking_event.valid?
  end

  test "occurred_at can be recent" do
    @tracking_event.occurred_at = 1.minute.ago
    assert @tracking_event.valid?
  end

  test "occurred_at preserves timezone" do
    time_with_zone = Time.zone.parse("2026-05-06 15:30:00")
    @tracking_event.occurred_at = time_with_zone
    @tracking_event.save!

    assert_equal time_with_zone.to_i, @tracking_event.reload.occurred_at.to_i
  end

  # ============================================================================
  # Data Integrity
  # ============================================================================

  test "handles long descriptions" do
    @tracking_event.description = "A" * 1000
    assert @tracking_event.valid?
  end

  test "handles long location names" do
    @tracking_event.location = "Very Long Location Name " * 10
    assert @tracking_event.valid?
  end

  test "handles special characters in tracking number" do
    @tracking_event.tracking_number = "1Z999AA10123456784"
    assert @tracking_event.valid?
  end

  test "handles unicode in description" do
    @tracking_event.description = "Package delayed due to weather ❄️ 🌨️"
    assert @tracking_event.valid?
  end

  # ============================================================================
  # Multiple Events for Same Tracking Number
  # ============================================================================

  test "allows multiple events for same tracking number" do
    tracking_num = "MULTI123456"

    event1 = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: tracking_num,
      event_type: "shipped",
      occurred_at: 2.days.ago
    )

    event2 = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: tracking_num,
      event_type: "in_transit",
      occurred_at: 1.day.ago
    )

    event3 = TrackingEvent.create!(
      order: orders(:one),
      carrier: "FedEx",
      tracking_number: tracking_num,
      event_type: "delivered",
      occurred_at: Time.current
    )

    events = TrackingEvent.for_tracking_number(tracking_num)
    assert_equal 3, events.count
  end

  # ============================================================================
  # Database Indexes
  # ============================================================================

  test "tracking_number is indexed for performance" do
    indexes = ActiveRecord::Base.connection.indexes(:tracking_events)
    tracking_number_indexes = indexes.select { |i| i.columns.include?("tracking_number") }
    assert tracking_number_indexes.any?, "Expected tracking_number to be indexed"
  end

  test "order_id and occurred_at composite index exists" do
    indexes = ActiveRecord::Base.connection.indexes(:tracking_events)
    composite_index = indexes.find { |i| i.columns == [ "order_id", "occurred_at" ] }
    assert composite_index, "Expected composite index on [order_id, occurred_at]"
  end

  # ============================================================================
  # Association Cascade
  # ============================================================================

  test "deleting order does not cascade to tracking events by default" do
    order = Order.create!(
      order_number: "TRACK-TEST-001",
      user: users(:one)
    )

    event = TrackingEvent.create!(
      order: order,
      carrier: "FedEx",
      tracking_number: "CASCADE-TEST",
      event_type: "shipped",
      occurred_at: Time.current
    )

    # Attempting to delete order with tracking events should fail due to FK constraint
    assert_raises(ActiveRecord::InvalidForeignKey) do
      order.delete
    end
  end
end
