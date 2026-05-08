require "test_helper"

class ProductTest < ActiveSupport::TestCase
  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    @product = products(:one)
  end

  # ============================================================================
  # Basic Validations
  # ============================================================================

  test "valid product" do
    assert @product.valid?
  end

  test "invalid without name" do
    @product.name = nil
    refute @product.valid?
    assert_includes @product.errors[:name], "can't be blank"
  end

  test "invalid without sku" do
    @product.sku = nil
    refute @product.valid?
    assert_includes @product.errors[:sku], "can't be blank"
  end

  test "invalid without price" do
    @product.price = nil
    refute @product.valid?
    assert_includes @product.errors[:price], "can't be blank"
  end

  test "invalid with negative price" do
    @product.price = -10.00
    refute @product.valid?
    assert_includes @product.errors[:price], "must be greater than or equal to 0"
  end

  test "valid with zero price" do
    @product.price = 0
    assert @product.valid?
  end

  test "invalid with non-numeric price" do
    @product.price = "not a number"
    refute @product.valid?
    assert_includes @product.errors[:price], "is not a number"
  end

  # ============================================================================
  # Uniqueness Validations
  # ============================================================================

  test "sku must be unique" do
    duplicate_product = Product.new(
      name: "Duplicate Product",
      sku: @product.sku,
      price: 19.99
    )
    refute duplicate_product.valid?
    assert_includes duplicate_product.errors[:sku], "has already been taken"
  end

  test "sku uniqueness is case sensitive" do
    @product.sku = "WIDGET-001"
    @product.save!

    different_case = Product.new(
      name: "Different Case Product",
      sku: "widget-001",
      price: 19.99
    )
    assert different_case.valid?
  end

  # ============================================================================
  # Associations
  # ============================================================================

  test "has many line_items" do
    assert_respond_to @product, :line_items
  end

  test "line_items association returns correct records" do
    order = orders(:one)
    line_item = LineItem.create!(
      order: order,
      product: @product,
      quantity: 2,
      unit_price: @product.price
    )

    assert_includes @product.line_items, line_item
  end

  test "cannot destroy product with associated line_items" do
    order = orders(:one)
    LineItem.create!(
      order: order,
      product: @product,
      quantity: 2,
      unit_price: @product.price
    )

    refute @product.destroy
    assert_includes @product.errors[:base], "Cannot delete record because dependent line items exist"
  end

  test "can destroy product without associated line_items" do
    product = Product.create!(
      name: "Temporary Product",
      sku: "TEMP-001",
      price: 9.99
    )

    assert product.destroy
    assert_nil Product.find_by(id: product.id)
  end

  # ============================================================================
  # Scopes
  # ============================================================================

  test "active scope excludes zero price products" do
    active_product = Product.create!(
      name: "Active Product",
      sku: "ACT-001",
      price: 10.00
    )
    inactive_product = Product.create!(
      name: "Inactive Product",
      sku: "INACT-001",
      price: 0
    )

    active_products = Product.active
    assert_includes active_products, active_product
    refute_includes active_products, inactive_product
  end

  test "ordered_by_name scope returns products in alphabetical order" do
    LineItem.delete_all
    Product.delete_all

    product_c = Product.create!(name: "Charlie Product", sku: "C-001", price: 10.00)
    product_a = Product.create!(name: "Alpha Product", sku: "A-001", price: 10.00)
    product_b = Product.create!(name: "Beta Product", sku: "B-001", price: 10.00)

    ordered = Product.ordered_by_name.to_a
    assert_equal [ product_a, product_b, product_c ], ordered
  end

  # ============================================================================
  # Helper Methods
  # ============================================================================

  test "formatted_price returns currency format" do
    @product.price = 29.99
    assert_equal "$29.99", @product.formatted_price
  end

  test "formatted_price handles whole numbers" do
    @product.price = 50
    assert_equal "$50.00", @product.formatted_price
  end

  test "formatted_price handles many decimal places" do
    @product.price = 19.999
    assert_equal "$20.00", @product.formatted_price
  end

  test "formatted_price handles zero" do
    @product.price = 0
    assert_equal "$0.00", @product.formatted_price
  end

  # ============================================================================
  # PaperTrail Integration
  # ============================================================================

  test "creates version on update" do
    assert_difference "@product.versions.count", 1 do
      @product.update!(name: "Updated Widget Pro")
    end
  end

  test "tracks changes in versions" do
    original_name = @product.name
    @product.update!(name: "New Name")

    last_version = @product.versions.last
    assert_equal "New Name", @product.name
    assert_equal "update", last_version.event

    @product.update!(
      name: "Updated Name",
      price: 39.99,
      description: "Updated description"
    )

    # Verify the product was updated
    assert_equal "Updated Name", @product.name
    assert_equal BigDecimal("39.99"), @product.price
    assert_equal "Updated description", @product.description

    # Verify a version was created
    last_version = @product.versions.last
    assert last_version.present?
    assert_equal "update", last_version.event
  end

  # ============================================================================
  # Edge Cases & Data Integrity
  # ============================================================================

  test "handles very large prices" do
    @product.price = 99999999.99
    assert @product.valid?
    @product.save!
    assert_equal 99999999.99, @product.reload.price
  end

  test "handles long product names" do
    @product.name = "A" * 255
    assert @product.valid?
  end

  test "handles long descriptions" do
    @product.description = "Long description " * 100
    assert @product.valid?
  end

  test "description is optional" do
    @product.description = nil
    assert @product.valid?
  end

  test "price precision is maintained" do
    @product.price = 19.95
    @product.save!
    assert_equal BigDecimal("19.95"), @product.reload.price
  end
end
