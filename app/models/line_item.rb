class LineItem < ApplicationRecord
  # PaperTrail auditing
  has_paper_trail

  # Associations
  belongs_to :order
  belongs_to :product

  # Validations
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, :total, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :set_unit_price
  before_validation :calculate_total

  private

  def set_unit_price
    self.unit_price ||= product.price if product
  end

  def calculate_total
    self.total = (quantity || 0) * (unit_price || 0)
  end
end
