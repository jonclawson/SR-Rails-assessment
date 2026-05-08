class TrackingEvent < ApplicationRecord
  # Associations
  belongs_to :order

  # Validations
  validates :carrier, presence: true
  validates :tracking_number, presence: true
  validates :event_type, presence: true
  validates :occurred_at, presence: true

  # Scopes
  scope :recent_first, -> { order(occurred_at: :desc) }
  scope :for_tracking_number, ->(number) { where(tracking_number: number) }
end
