require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  def setup
    @order = orders(:one)
    @product = products(:one)
    @line_item = LineItem.new(
      order: @order,
      product: @product,
      quantity: 2
    )
  end

  # Association tests
  test "should belong to order" do
    assert_respond_to @line_item, :order
    @line_item.order = nil
    assert_not @line_item.valid?
  end

  test "should belong to product" do
    assert_respond_to @line_item, :product
    @line_item.product = nil
    assert_not @line_item.valid?
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @line_item.valid?
  end

  test "should require quantity" do
    @line_item.quantity = nil
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:quantity], "can't be blank"
  end

  test "should require quantity to be an integer" do
    @line_item.quantity = 1.5
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:quantity], "must be an integer"
  end

  test "should require quantity to be greater than zero" do
    @line_item.quantity = 0
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:quantity], "must be greater than 0"

    @line_item.quantity = -1
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:quantity], "must be greater than 0"
  end

  test "should accept positive integer quantity" do
    @line_item.quantity = 5
    assert @line_item.valid?
  end

  test "should require unit_price to be present" do
    @line_item.unit_price = nil
    @line_item.product = nil # Prevent auto-setting from product
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:unit_price], "can't be blank"
  end

  test "should require unit_price to be greater than or equal to zero" do
    @line_item.unit_price = -1
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:unit_price], "must be greater than or equal to 0"

    @line_item.unit_price = 0
    assert @line_item.valid?
  end

  test "should require total to be present" do
    # Skip callback to test validation directly
    @line_item.define_singleton_method(:calculate_total) { }
    @line_item.total = nil
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:total], "can't be blank"
  end

  test "should require total to be greater than or equal to zero" do
    # Skip callback to test validation directly
    @line_item.define_singleton_method(:calculate_total) { }
    @line_item.total = -1
    assert_not @line_item.valid?
    assert_includes @line_item.errors[:total], "must be greater than or equal to 0"

    @line_item.total = 0
    assert @line_item.valid?
  end

  # Callback tests
  test "should automatically set unit_price from product price" do
    line_item = LineItem.new(
      order: @order,
      product: @product,
      quantity: 2
    )
    assert_nil line_item.unit_price
    line_item.valid? # Trigger callbacks
    assert_equal @product.price, line_item.unit_price
  end

  test "should not override manually set unit_price" do
    custom_price = 15.99
    line_item = LineItem.new(
      order: @order,
      product: @product,
      quantity: 2,
      unit_price: custom_price
    )
    line_item.valid? # Trigger callbacks
    assert_equal custom_price, line_item.unit_price
  end

  test "should automatically calculate total from quantity and unit_price" do
    @line_item.quantity = 3
    @line_item.unit_price = 10.00
    @line_item.valid? # Trigger callbacks
    assert_equal 30.00, @line_item.total
  end

  test "should recalculate total when quantity changes" do
    @line_item.quantity = 2
    @line_item.unit_price = 5.00
    @line_item.save!
    assert_equal 10.00, @line_item.total

    @line_item.quantity = 5
    @line_item.save!
    assert_equal 25.00, @line_item.total
  end

  test "should recalculate total when unit_price changes" do
    @line_item.quantity = 3
    @line_item.unit_price = 10.00
    @line_item.save!
    assert_equal 30.00, @line_item.total

    @line_item.unit_price = 15.00
    @line_item.save!
    assert_equal 45.00, @line_item.total
  end

  test "should handle zero quantity in total calculation" do
    @line_item.quantity = 0
    @line_item.unit_price = 10.00
    # Will be invalid due to quantity validation, but total should still calculate
    @line_item.validate
    assert_equal 0.00, @line_item.total
  end

  test "should handle nil values gracefully in total calculation" do
    line_item = LineItem.new(
      order: @order,
      quantity: nil,
      unit_price: nil
    )
    line_item.validate # Trigger callbacks
    assert_equal 0.00, line_item.total
  end

  # PaperTrail auditing test
  test "should track changes with paper_trail" do
    @line_item.save!
    assert_respond_to @line_item, :versions

    initial_version_count = @line_item.versions.count
    @line_item.update!(quantity: 5)
    assert_equal initial_version_count + 1, @line_item.versions.count
  end

  # Integration test
  test "should create valid line_item with product and calculate total" do
    line_item = LineItem.create!(
      order: @order,
      product: @product,
      quantity: 4
    )

    assert line_item.persisted?
    assert_equal @product.price, line_item.unit_price
    assert_equal @product.price * 4, line_item.total
  end
end
