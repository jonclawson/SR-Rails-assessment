class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :sku
      t.decimal :price, precision: 10, scale: 2
      t.text :description

      t.timestamps
    end
    add_index :products, :sku, unique: true
  end
end
