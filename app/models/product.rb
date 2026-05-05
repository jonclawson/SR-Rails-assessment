class Product < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Associations
  has_many :line_items, dependent: :restrict_with_error

  # Scopes
  scope :active, -> { where.not(price: 0) }
  scope :ordered_by_name, -> { order(:name) }

  # Helper methods
  def formatted_price
    "$#{format('%.2f', price)}"
  end
end
