class OrdersController < ApplicationController
  before_action :require_authentication
  before_action :set_order, only: [ :show, :edit, :update ]

  # GET /orders
  # Dashboard with filtering, search, and pagination
  def index
    @orders = Order.includes(:user, :line_items, :products)
                   .order(created_at: :desc)

    # Filter by state
    if params[:state].present? && OrderStateMachine::STATES.include?(params[:state])
      @orders = @orders.in_state(params[:state])
    end

    # Search by order number or customer email
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orders = @orders.left_joins(:user)
                       .where("orders.order_number ILIKE ? OR users.email_address ILIKE ?",
                              search_term, search_term)
    end

    # Pagination (30 per page)
    @orders = @orders.page(params[:page]).per(30)

    # State counts for filter tabs
    @state_counts = OrderStateMachine::STATES.index_with do |state|
      Order.in_state(state).count
    end
  end

  # GET /orders/:id
  def show
    @tracking_events = @order.tracking_events.recent_first
    @order_transitions = @order.order_transitions.order(created_at: :desc)
    @versions = @order.versions.order(created_at: :desc)
  end

  # GET /orders/new
  def new
    @order = Order.new
    @order.line_items.build
    @products = Product.active.ordered_by_name
  end

  # POST /orders
  def create
    @order = Order.new(order_params)
    @order.user = Current.user

    if @order.save
      redirect_to @order, notice: "Order #{@order.order_number} was successfully created."
    else
      @products = Product.active.ordered_by_name
      render :new, status: :unprocessable_entity
    end
  end

  # GET /orders/:id/edit
  def edit
    @products = Product.active.ordered_by_name
  end

  # PATCH/PUT /orders/:id
  def update
    # Handle state transition if to_state param is present
    if params[:to_state].present?
      service = Orders::TransitionService.new(@order, to_state: params[:to_state], user: Current.user)

      if service.call
        redirect_to @order, notice: "Order transitioned to #{params[:to_state]}"
      else
        redirect_to @order, alert: service.errors.join(", ")
      end
    # Handle regular attribute updates
    elsif @order.update(order_params)
      redirect_to @order, notice: "Order was successfully updated."
    else
      @products = Product.active.ordered_by_name
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /orders/bulk_update
  # Bulk transition multiple orders
  def bulk_update
    order_ids = params[:order_ids] || []
    to_state = params[:to_state]

    if order_ids.empty?
      redirect_to orders_path, alert: "No orders selected"
      return
    end

    unless to_state.present? && OrderStateMachine::STATES.include?(to_state)
      redirect_to orders_path, alert: "Invalid state selected"
      return
    end

    service = Orders::BulkTransitionService.new(order_ids, to_state: to_state, user: Current.user)
    service.call

    if service.failure_count.zero?
      redirect_to orders_path, notice: service.summary_message
    else
      # Show detailed errors
      flash[:alert] = service.summary_message
      flash[:errors] = service.results[:failed]
      redirect_to orders_path
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to orders_path, alert: "Order not found"
  end

  def order_params
    params.require(:order).permit(
      line_items_attributes: [ :id, :product_id, :quantity, :_destroy ]
    )
  end
end
