# Simulates external carrier API calls for tracking information
# In production, this would be replaced with real carrier API integrations
class CarrierApiSimulator
  CARRIERS = %w[USPS FedEx UPS DHL].freeze

  EVENT_TYPES = {
    shipped: "Package picked up",
    in_transit: "In transit",
    out_for_delivery: "Out for delivery",
    delivered: "Delivered"
  }.freeze

  LOCATIONS = [
    "Los Angeles, CA",
    "Chicago, IL",
    "Houston, TX",
    "Phoenix, AZ",
    "Philadelphia, PA",
    "San Antonio, TX",
    "San Diego, CA",
    "Dallas, TX",
    "San Jose, CA",
    "Austin, TX"
  ].freeze

  # Simulates fetching tracking updates from carrier API
  # Returns array of tracking events
  def self.fetch_tracking_updates(tracking_number, carrier: CARRIERS.sample)
    # Simulate API delay (0.5 to 2 seconds)
    sleep(rand(0.5..2.0))

    # Simulate occasional API failures (5% chance)
    raise ApiError, "Carrier API temporarily unavailable" if rand < 0.05

    # Generate realistic tracking events based on order age
    generate_tracking_events(tracking_number, carrier)
  end

  # Simulates initial carrier API call to create shipping label
  # Returns generated tracking number
  def self.create_shipment(order, carrier: CARRIERS.sample)
    # Simulate API delay
    sleep(rand(0.3..1.0))

    # Generate tracking number (carrier-specific format)
    generate_tracking_number(carrier)
  end

  class << self
    private

    def generate_tracking_number(carrier)
      case carrier
      when "USPS"
        # USPS format: 9400 1000 0000 0000 0000 00
        "9400#{rand(1000..9999)}#{rand(10000000000000..99999999999999)}"
      when "FedEx"
        # FedEx format: 12 digits
        rand(100000000000..999999999999).to_s
      when "UPS"
        # UPS format: 1Z XXX XXX XX XXXX XXX X
        "1Z#{('A'..'Z').to_a.sample(3).join}#{rand(100..999)}#{rand(10..99)}#{rand(1000..9999)}#{rand(100..999)}#{rand(0..9)}"
      when "DHL"
        # DHL format: 10-11 digit number
        rand(10000000000..99999999999).to_s
      else
        # Generic format
        "TRACK#{rand(1000000000..9999999999)}"
      end
    end

    def generate_tracking_events(tracking_number, carrier)
      events = []
      base_time = Time.current - rand(1..5).days

      # Initial pickup event
      events << {
        carrier: carrier,
        tracking_number: tracking_number,
        event_type: "shipped",
        description: EVENT_TYPES[:shipped],
        location: LOCATIONS.sample,
        occurred_at: base_time
      }

      # Random number of in-transit events (1-4)
      transit_count = rand(1..4)
      transit_count.times do |i|
        base_time += rand(4..12).hours
        events << {
          carrier: carrier,
          tracking_number: tracking_number,
          event_type: "in_transit",
          description: EVENT_TYPES[:in_transit],
          location: LOCATIONS.sample,
          occurred_at: base_time
        }
      end

      # 70% chance of out for delivery event
      if rand < 0.7
        base_time += rand(6..18).hours
        events << {
          carrier: carrier,
          tracking_number: tracking_number,
          event_type: "out_for_delivery",
          description: EVENT_TYPES[:out_for_delivery],
          location: LOCATIONS.sample,
          occurred_at: base_time
        }

        # 80% chance of delivery if out for delivery
        if rand < 0.8
          base_time += rand(2..8).hours
          events << {
            carrier: carrier,
            tracking_number: tracking_number,
            event_type: "delivered",
            description: EVENT_TYPES[:delivered],
            location: LOCATIONS.sample,
            occurred_at: base_time
          }
        end
      end

      events
    end
  end

  class ApiError < StandardError; end
end
