class CreateOrderTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :order_transitions do |t|
      t.references :order, null: false, foreign_key: true
      t.string :to_state, null: false
      t.jsonb :metadata, default: {}
      t.boolean :most_recent, null: false
      t.integer :sort_key, null: false

      t.timestamps null: false
    end

    add_index :order_transitions, [ :order_id, :sort_key ], unique: true
    add_index :order_transitions, [ :order_id, :most_recent ], unique: true, where: "most_recent = TRUE"
  end
end
