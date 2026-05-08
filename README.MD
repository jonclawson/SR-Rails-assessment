# ShipRight Operations Dashboard

A comprehensive Rails 8 operations fulfillment platform for managing orders through their complete lifecycle from pending to delivery.

## Design considerations

1. The State Machine
  
   Rather than custom if/else logic in the controller this app uses a State Machine.

   Statesman gem was chosen because it decouples state logic from the model and provides an easy path for the Audit History requirement (it records every transition in a separate table by default).

   Logic:

   `pending -> reviewed -> shipped -> delivered.`

   This ensures that "shipping before review" is physically impossible at the database/model level.

2. Audit History  

   This tool could apply to other models.

   The PaperTrail gem is an Industry standard for Rails auditing. It handles "who, what, when" out of the box. If you want to show off "Architecture," implement a simple polymorphic ActivityLog that records record_id, record_type, event_description, and metadata (JSONB).

3. Data Integrity & Precision
   For money, the type used is decimal with precision: 10, scale: 2. The money-rails gem was also a consideration.

   Validations uses greater or equal to 0 for prices.

4. External Integration: Carrier Tracking

   Solid Queue was chosen over Sidekiq/redis as a (standard in Rails 8). 
   When an order is marked "Shipped," it triggers a tracking job.

   Live Updates use Turbo Streams. When the background job finishes, broadcast the update so the view refreshes without a page reload.Very Railsish.

5. UI & Bulk Actions
   Authentication uses the Rails 8 built-in authentication generator (bin/rails generate authentication) rather than Devise previously the standard. It's cleaner and is up to date with the latest framework features.

   Bulk Actions use checkboxes in index view.

## 🚀 Features

### Core Functionality
- **Staff Authentication** - Rails 8 built-in authentication with `has_secure_password`
- **Order Management** - Full CRUD operations with dynamic line items
- **State Machine** - Order lifecycle management (pending → approved → shipped → delivered, with cancellation support)
- **Audit Trail** - Complete history tracking with PaperTrail
- **Carrier Tracking** - Simulated carrier API integration with realistic tracking events
- **Dashboard** - Filterable, searchable order list with bulk operations
- **Real-time Calculations** - Dynamic order totals with 8% tax calculation

### Order States
```
pending → approved → shipped → delivered
   ↓          ↓
canceled   canceled
```

**State Rules:**
- Orders must have line items before shipping
- Delivered orders cannot be canceled
- State transitions are tracked with timestamps and metadata
- Background jobs sync tracking data for shipped orders

## 🛠 Technology Stack

- **Rails** 8.1.3
- **Ruby** 3.3.10
- **PostgreSQL** - Primary database
- **Statesman** 12.1.0 - State machine with ActiveRecord adapter
- **PaperTrail** 15.2.0 - Audit logging
- **Tailwind CSS** - Styling via Propshaft
- **Hotwire/Turbo** - Reactive UI
- **Solid Queue** - Background job processing
- **Kaminari** - Pagination
- **Faker** - Seed data generation

## 📋 Prerequisites

- Ruby 3.3.10 (via asdf or rbenv)
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)

## 🚦 Getting Started
Normaly, I would have used docker to run the app, but the requirements explicitly requested no docker or CI/CD. 

### Clone Repo
```bash
git clone 
cd SR-Rails-assessmentt

```

### Quick Setup
```
bin/setup
bin/rails db:seed
```
Navigate to `http://localhost:3000` and login with:

```
Email: staff@shipright.com
Password: password
```

### Manual steps

### 1. Install

```bash
git clone 
cd SR-Rails-assessmentt
bundle install

```

### 2. Database Setup

```bash
# Create and setup database
bin/rails db:create db:migrate

# Load seed data (creates 78 orders with full history)
bin/rails db:seed
```

**Seed Data Includes:**
- 1 staff user
- 30 products (various SKUs and prices)
- 78 orders distributed across all states:
  - 15 pending
  - 12 approved  
  - 9 shipped (with tracking)
  - 34 delivered (with complete tracking history)
  - 8 canceled
- 230+ line items
- 143 state transitions
- 280+ tracking events
- 1,281 audit trail versions

### 3. Start the Application

```bash
# Start Rails server, Tailwind CSS watcher, and Solid Queue worker
bin/dev

# Or start components individually:
bin/rails server        # Port 3000
bin/rails tailwindcss:watch
bin/rails solid_queue:start
```

### 4. Login

Navigate to `http://localhost:3000` and login with:

```
Email: staff@shipright.com
Password: password
```

## 📖 Usage Guide

### Dashboard Operations

**Filtering:**
- Click state tabs to filter orders by status
- Use search bar to find orders by number or customer email
- View order counts for each state

**Bulk Operations:**
- Select multiple orders using checkboxes
- Choose target state from dropdown
- Click "Apply to Selected" to transition all at once
- Success/failure results displayed with details

**Creating Orders:**
1. Click "New Order" button
2. Select products and quantities
3. Add/remove line items as needed
4. See real-time total calculations
5. Submit - order starts in "pending" state

**Managing Orders:**
- View individual order details with tracking timeline
- See complete state transition history
- Review audit trail showing all changes
- Use "Quick Actions" buttons to transition states
- Edit orders (limited for processed orders)

### State Transitions

Orders can be transitioned through their lifecycle:

```ruby
# Via UI
- Click quick action buttons on order detail page
- Use bulk update from dashboard

# Via Rails console
order = Order.find_by(order_number: "ORD-ABC123")
order.transition_to!(:approved)
order.transition_to!(:shipped)  # Generates tracking number, queues sync job
```

**Guard Validations:**
- Cannot ship orders without line items
- Cannot cancel delivered orders
- All transitions logged with audit trail

### Carrier Tracking

When an order is marked as "shipped":
1. Tracking number is auto-generated
2. `SyncTrackingJob` is queued
3. Background job simulates carrier API calls
4. Tracking events are created with timestamps
5. Order auto-transitions to "delivered" when tracking shows delivery

**Simulated Carriers:**
- USPS (tracking format: 9400...)
- FedEx (12 digits)
- UPS (1Z...)
- DHL (10-11 digits)

## 🏗 Architecture

### Models

**Order**
- Belongs to user
- Has many line_items, order_transitions, tracking_events
- Statesman integration for state management
- Auto-generates order numbers (ORD-XXXXXXXXXX)
- Calculates totals with 8% tax rate

**LineItem**
- Belongs to order and product
- Auto-sets unit price from product
- Calculates total (quantity × unit_price)

**Product**
- Basic catalog item with name, SKU, price, description
- Scopes: `active` (price > 0), `ordered_by_name`

**OrderTransition**
- Stores state history for Statesman
- JSONB metadata column (no serialization needed)
- Tracks sort order and most_recent flag

**TrackingEvent**
- Records carrier tracking updates
- Fields: carrier, tracking_number, event_type, location, occurred_at
- Scopes: `recent_first`, `for_tracking_number`

### Services

**Orders::TransitionService**
- Single order state transitions
- PaperTrail integration for audit tracking
- Error handling with friendly messages

**Orders::BulkTransitionService**
- Multiple order transitions
- Returns success/failure results
- Detailed error reporting per order

**CarrierApiSimulator**
- Simulates external carrier APIs
- Realistic tracking event generation
- Random delays and failure rates (5%)

### Jobs

**SyncTrackingJob**
- Fetches tracking updates from carrier simulator
- Creates TrackingEvent records (avoids duplicates)
- Auto-transitions to delivered when tracking shows delivery
- Retry logic for API failures (exponential backoff, 5 attempts)

### Controllers

**OrdersController**
- Full CRUD operations
- Filtering by state
- Search by order number or email
- Kaminari pagination (30 per page)
- Bulk update action for mass transitions

## 🗄 Database Schema

**Key Tables:**
- `users` - Staff authentication
- `sessions` - Authentication sessions
- `products` - Product catalog
- `orders` - Order records with totals
- `line_items` - Order items with quantities and prices
- `order_transitions` - State machine history (JSONB metadata)
- `tracking_events` - Carrier tracking data
- `versions` - PaperTrail audit log

**Money Handling:**
All monetary values use `decimal(10,2)` precision for accurate currency calculations.

## 🔧 Configuration

### Statesman Setup

The application uses Statesman with ActiveRecord adapter (configured in `config/initializers/statesman.rb`):

```ruby
Statesman.configure do
  storage_adapter(Statesman::Adapters::ActiveRecord)
end
```

**Important:** The `OrderTransition` model does NOT include `Statesman::Adapters::ActiveRecordTransition` because we use a native JSONB column which doesn't need serialization.

### PaperTrail Configuration

All changes to orders, line items, and products are tracked. The current user is automatically recorded via `ApplicationController.set_paper_trail_whodunnit`.

**Note:** PaperTrail 15.2.0 shows a compatibility warning with Rails 8.1.3 but functions correctly for development use.

## 🧪 Testing

```bash
# Run end to end Rspec tests
bundle exec rspec

# Run unit tests
bin/rails test

# Run specific test file
bin/rails test test/models/order_test.rb

# Run with coverage
COVERAGE=true bin/rails test
```

### Test Coverage Areas
- **Models:** Validations, associations, state machine guards, calculations
- **Services:** Transition logic, bulk operations, error handling
- **Controllers:** CRUD operations, filtering, search, bulk actions
- **System Tests:** End-to-end workflows, authentication, order lifecycle

## 🐛 Known Issues

1. **PaperTrail Compatibility Warning**
   - PaperTrail 15.2.0 shows compatibility warning with Rails 8.1.3
   - Functionally works but may need upgrade when compatible version releases
   - Can silence warning with: `export PAPER_TRAIL_COMPATIBLE=true`

2. **Statesman Configuration**
   - Must explicitly configure ActiveRecord adapter in initializer
   - Default Memory adapter won't persist transitions
   - JSONB metadata columns require special handling (no ActiveRecordTransition module)

3. **Asset Compilation**
   - First load may be slow while Tailwind compiles
   - Run `bin/rails tailwindcss:build` before deploying to production


## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Development Notes

### Rails 8 Conventions
- Uses built-in authentication (no Devise)
- Solid Queue for background jobs (no Sidekiq/Resque)
- Propshaft for assets (no Sprockets/Webpacker)
- Hotwire/Turbo for reactive UI (minimal JavaScript)

### Code Organization
- Service objects in `app/services/orders/`
- State machines in `app/state_machines/`
- Background jobs in `app/jobs/`
- View partials for reusable components

### Design Patterns
- **Service Objects:** Encapsulate business logic (transitions, bulk operations)
- **State Machine:** Statesman manages order lifecycle with guards and callbacks
- **Auditing:** PaperTrail tracks all changes with user context
- **Background Jobs:** Solid Queue handles async tracking sync


**Documentation Version:** 1.0  
**Last Updated:** May 5, 2026  
**Rails Version:** 8.1.3  
**Ruby Version:** 3.3.10
