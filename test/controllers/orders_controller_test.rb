require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @order = orders(:one)
    @product = products(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get orders_path
    assert_response :success
  end

  test "should get show" do
    get order_path(@order)
    assert_response :success
  end

  test "should get new" do
    get new_order_path
    assert_response :success
  end

  test "should create order" do
    assert_difference("Order.count") do
      post orders_path, params: {
        order: {
          line_items_attributes: {
            "0" => { product_id: @product.id, quantity: 1 }
          }
        }
      }
    end
    assert_redirected_to order_path(Order.last)
  end

  test "should get edit" do
    get edit_order_path(@order)
    assert_response :success
  end

  test "should update order" do
    patch order_path(@order), params: {
      order: {
        line_items_attributes: {
          "0" => { product_id: @product.id, quantity: 2 }
        }
      }
    }
    assert_redirected_to order_path(@order)
  end

  test "should bulk update orders" do
    # Ensure order is in pending state (created via fixtures may not have transitions yet)
    assert_equal "pending", @order.current_state

    post bulk_update_orders_path, params: {
      order_ids: [ @order.id ],
      to_state: "approved"
    }

    assert_redirected_to orders_path
    assert_not_nil flash[:notice], "Expected flash notice to be set"
    assert_match /successfully/i, flash[:notice]

    # Verify the order state changed
    @order.reload
    assert_equal "approved", @order.current_state
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end
