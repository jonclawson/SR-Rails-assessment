# Service object for transitioning orders between states
# Provides consistent error handling and business logic
module Orders
  class TransitionService
    attr_reader :order, :to_state, :user, :errors

    def initialize(order, to_state:, user:)
      @order = order
      @to_state = to_state.to_s
      @user = user
      @errors = []
    end

    def call
      return false unless valid?

      begin
        # Set PaperTrail context for auditing
        PaperTrail.request(whodunnit: user.id) do
          order.transition_to!(to_state)
          # Touch the order to create a PaperTrail version with the state change
          order.touch
        end

        true
      rescue Statesman::GuardFailedError => e
        @errors << "Cannot transition to #{to_state}: #{e.message}"
        false
      rescue Statesman::TransitionFailedError => e
        @errors << "Transition failed: #{e.message}"
        false
      rescue StandardError => e
        Rails.logger.error "Orders::TransitionService error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @errors << "An unexpected error occurred"
        false
      end
    end

    # Class method for convenience
    def self.call(order, to_state:, user:)
      new(order, to_state: to_state, user: user).call
    end

    private

    def valid?
      unless order.persisted?
        @errors << "Order must be saved first"
        return false
      end

      unless order.can_transition_to?(to_state)
        available_states = order.state_machine.allowed_transitions.join(", ")
        @errors << "Cannot transition from #{order.current_state} to #{to_state}. Available: #{available_states}"
        return false
      end

      true
    end
  end
end
