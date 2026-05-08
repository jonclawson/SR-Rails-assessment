class AddTrackingNumberToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :tracking_number, :string
  end
end
