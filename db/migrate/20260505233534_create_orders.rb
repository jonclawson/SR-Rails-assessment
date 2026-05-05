class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :order_number
      t.decimal :subtotal, precision: 10, scale: 2
      t.decimal :tax, precision: 10, scale: 2
      t.decimal :total, precision: 10, scale: 2
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :orders, :order_number, unique: true
  end
end
