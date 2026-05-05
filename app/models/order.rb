class Order < ApplicationRecord
  # PaperTrail auditing
  has_paper_trail

  # Associations
  belongs_to :user
  has_many :line_items, dependent: :destroy
  has_many :products, through: :line_items
  has_many :order_transitions, autosave: false, dependent: :destroy
  has_many :tracking_events, dependent: :destroy

  # Statesman integration
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: OrderTransition,
    initial_state: :pending
  ]

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :subtotal, :tax, :total, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :search, ->(query) { where("order_number ILIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? }

  # Callbacks
  before_validation :generate_order_number, on: :create
  before_validation :calculate_totals

  # State machine methods
  def state_machine
    @state_machine ||= OrderStateMachine.new(self, transition_class: OrderTransition)
  end

  def current_state
    state_machine.current_state
  end

  delegate :can_transition_to?, :transition_to!, :transition_to, :in_state?, to: :state_machine

  # Helper methods
  def formatted_total
    "$#{format('%.2f', total)}"
  end

  def calculate_totals
    self.subtotal = line_items.sum(&:total)
    self.tax = (subtotal * 0.08).round(2) # 8% tax rate
    self.total = subtotal + tax
  end

  private

  def generate_order_number
    self.order_number ||= "ORD-#{SecureRandom.alphanumeric(10).upcase}"
  end
end
