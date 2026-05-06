# Clear existing data (for development only)
puts "🗑️  Cleaning up existing data..."
OrderTransition.delete_all
TrackingEvent.delete_all
LineItem.delete_all
Order.delete_all
Product.delete_all
User.delete_all

puts "👤 Creating staff user..."
staff_user = User.create!(
  email_address: "staff@shipright.com",
  password: "password"
)
puts "✅ Created staff user: #{staff_user.email_address} / password"

puts "\n📦 Creating products..."
products = []

# Tech Products
30.times do
  products << Product.create!(
    name: Faker::Commerce.product_name,
    sku: Faker::Barcode.ean,
    price: Faker::Commerce.price(range: 9.99..499.99),
    description: Faker::Lorem.paragraph(sentence_count: 2)
  )
end

puts "✅ Created #{products.count} products"

puts "\n🛒 Creating orders with various states..."

# Helper to create orders in specific states
def create_order_in_state(user, products, target_state, days_ago: rand(1..30))
  # Set PaperTrail whodunnit for audit trail
  PaperTrail.request.whodunnit = user.id

  # Create order in initial state
  order = Order.new(user: user)

  # Add 1-5 random line items
  items_count = rand(1..5)
  items_count.times do
    product = products.sample
    order.line_items.build(
      product: product,
      quantity: rand(1..3)
    )
  end

  order.created_at = days_ago.days.ago
  order.save!

  # Update timestamps to simulate order history
  order.update_columns(created_at: days_ago.days.ago, updated_at: days_ago.days.ago)

  # Progress through states based on target state
  case target_state.to_sym
  when :approved
    order.transition_to!(:approved)

  when :shipped
    order.transition_to!(:approved)
    order.transition_to!(:shipped)

    # Generate tracking events for shipped orders
    if order.tracking_number.present?
      create_tracking_events(order, :in_progress)
    end

  when :delivered
    order.transition_to!(:approved)
    order.transition_to!(:shipped)

    # Generate tracking events and mark as delivered
    if order.tracking_number.present?
      create_tracking_events(order, :delivered)
      order.transition_to!(:delivered)
    end

  when :canceled
    # Cancel the order (can be canceled from pending or approved)
    if rand < 0.5
      order.transition_to!(:approved)
    end
    order.transition_to!(:canceled)
  end

  order
end

def create_tracking_events(order, status)
  carrier = CarrierApiSimulator::CARRIERS.sample
  base_time = order.order_transitions.where(to_state: 'shipped').last.created_at

  # Shipped event
  order.tracking_events.create!(
    carrier: carrier,
    tracking_number: order.tracking_number,
    event_type: 'shipped',
    description: 'Package picked up',
    location: CarrierApiSimulator::LOCATIONS.sample,
    occurred_at: base_time
  )

  # In transit events
  rand(1..3).times do |i|
    base_time += rand(6..18).hours
    order.tracking_events.create!(
      carrier: carrier,
      tracking_number: order.tracking_number,
      event_type: 'in_transit',
      description: 'In transit',
      location: CarrierApiSimulator::LOCATIONS.sample,
      occurred_at: base_time
    )
  end

  if status == :delivered
    # Out for delivery
    base_time += rand(6..12).hours
    order.tracking_events.create!(
      carrier: carrier,
      tracking_number: order.tracking_number,
      event_type: 'out_for_delivery',
      description: 'Out for delivery',
      location: CarrierApiSimulator::LOCATIONS.sample,
      occurred_at: base_time
    )

    # Delivered
    base_time += rand(2..6).hours
    order.tracking_events.create!(
      carrier: carrier,
      tracking_number: order.tracking_number,
      event_type: 'delivered',
      description: 'Delivered',
      location: CarrierApiSimulator::LOCATIONS.sample,
      occurred_at: base_time
    )
  end
end

# Create orders distributed across states
state_distribution = {
  pending: 15,
  approved: 12,
  shipped: 18,
  delivered: 25,
  canceled: 8
}

state_distribution.each do |state, count|
  print "  Creating #{count} #{state} orders..."
  count.times do
    create_order_in_state(staff_user, products, state)
  end
  puts " ✅"
end

puts "\n📊 Seed data summary:"
puts "  Users: #{User.count}"
puts "  Products: #{Product.count}"
puts "  Orders: #{Order.count}"
puts "    - Pending: #{Order.in_state(:pending).count}"
puts "    - Approved: #{Order.in_state(:approved).count}"
puts "    - Shipped: #{Order.in_state(:shipped).count}"
puts "    - Delivered: #{Order.in_state(:delivered).count}"
puts "    - Canceled: #{Order.in_state(:canceled).count}"
puts "  Line Items: #{LineItem.count}"
puts "  Order Transitions: #{OrderTransition.count}"
puts "  Tracking Events: #{TrackingEvent.count}"
puts "  Audit Trail (PaperTrail): #{PaperTrail::Version.count} versions"

puts "\n✨ Seeding complete!"
puts "\n🔐 Login credentials:"
puts "  Email: staff@shipright.com"
puts "  Password: password"
