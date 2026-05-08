class OrderStateMachine
  include Statesman::Machine

  # All possible states
  STATES = %w[pending approved shipped delivered canceled].freeze

  # Define states
  state :pending, initial: true
  state :approved
  state :shipped
  state :delivered
  state :canceled

  # Define transitions with guards
  transition from: :pending, to: [ :approved, :canceled ]
  transition from: :approved, to: [ :shipped, :canceled ]
  transition from: :shipped, to: :delivered

  # Guard: Can't ship without line items
  guard_transition(to: :shipped) do |order|
    order.line_items.any?
  end

  # Guard: Can't cancel if delivered
  guard_transition(to: :canceled) do |order|
    !order.in_state?(:delivered)
  end

  # After transition callbacks
  after_transition(to: :shipped) do |order|
    # Queue tracking sync job when order is shipped
    SyncTrackingJob.perform_later(order.id) if defined?(SyncTrackingJob)

    # Generate tracking number if not present
    order.update(tracking_number: generate_tracking_number) unless order.tracking_number.present?
  end

  private

  def self.generate_tracking_number
    "TRK#{SecureRandom.alphanumeric(12).upcase}"
  end
end
