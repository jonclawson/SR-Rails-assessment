# Service object for bulk transitioning multiple orders
# Returns detailed success/failure summary
module Orders
  class BulkTransitionService
    attr_reader :order_ids, :to_state, :user, :results

    def initialize(order_ids, to_state:, user:)
      @order_ids = Array(order_ids).map(&:to_i).uniq
      @to_state = to_state.to_s
      @user = user
      @results = { succeeded: [], failed: [] }
    end

    def call
      return false if order_ids.empty?

      Order.where(id: order_ids).find_each do |order|
        service = TransitionService.new(order, to_state: to_state, user: user)

        if service.call
          @results[:succeeded] << {
            id: order.id,
            order_number: order.order_number,
            previous_state: order.order_transitions[-2]&.to_state || "unknown",
            new_state: order.current_state
          }
        else
          @results[:failed] << {
            id: order.id,
            order_number: order.order_number,
            current_state: order.current_state,
            errors: service.errors
          }
        end
      end

      results[:succeeded].any?
    end

    # Class method for convenience
    def self.call(order_ids, to_state:, user:)
      new(order_ids, to_state: to_state, user: user).call
    end

    def success_count
      results[:succeeded].count
    end

    def failure_count
      results[:failed].count
    end

    def total_count
      order_ids.count
    end

    def summary_message
      if failure_count.zero?
        "Successfully transitioned #{success_count} order(s) to #{to_state}"
      elsif success_count.zero?
        "Failed to transition any orders"
      else
        "Transitioned #{success_count} of #{total_count} order(s). #{failure_count} failed."
      end
    end
  end
end
