# Background job to sync tracking information from carrier APIs
class SyncTrackingJob < ApplicationJob
  queue_as :default

  retry_on CarrierApiSimulator::ApiError, wait: :exponentially_longer, attempts: 5

  def perform(order_id)
    order = Order.find(order_id)
    
    # Don't sync if order doesn't have a tracking number yet
    return unless order.tracking_number.present?
    
    # Fetch tracking updates from simulated carrier API
    tracking_updates = CarrierApiSimulator.fetch_tracking_updates(
      order.tracking_number
    )
    
    # Create tracking events (skip duplicates based on occurred_at + event_type)
    tracking_updates.each do |update|
      order.tracking_events.find_or_create_by(
        occurred_at: update[:occurred_at],
        event_type: update[:event_type]
      ) do |event|
        event.carrier = update[:carrier]
        event.tracking_number = update[:tracking_number]
        event.description = update[:description]
        event.location = update[:location]
      end
    end

    # Broadcast update via Turbo Stream if order is being watched
    broadcast_tracking_update(order) if order.tracking_events.any?

    # Auto-transition to delivered state if tracking shows delivered
    if delivered_event = order.tracking_events.find_by(event_type: "delivered")
      if order.in_state?(:shipped) && order.can_transition_to?(:delivered)
        order.transition_to!(:delivered)
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "SyncTrackingJob: Order #{order_id} not found"
  rescue CarrierApiSimulator::ApiError => e
    Rails.logger.error "SyncTrackingJob: Carrier API error for order #{order_id}: #{e.message}"
    raise # Re-raise to trigger retry
  rescue StandardError => e
    Rails.logger.error "SyncTrackingJob: Unexpected error for order #{order_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def broadcast_tracking_update(order)
    # Will implement Turbo Stream broadcasting when we build the views
    # Turbo::StreamsChannel.broadcast_replace_to(
    #   "order_#{order.id}",
    #   target: "tracking_timeline",
    #   partial: "orders/tracking_timeline",
    #   locals: { order: order }
    # )
  end
end
