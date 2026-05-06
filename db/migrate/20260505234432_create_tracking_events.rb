class CreateTrackingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :tracking_events do |t|
      t.references :order, null: false, foreign_key: true
      t.string :carrier
      t.string :tracking_number
      t.string :event_type
      t.text :description
      t.string :location
      t.datetime :occurred_at

      t.timestamps
    end

    add_index :tracking_events, :tracking_number
    add_index :tracking_events, [ :order_id, :occurred_at ]
  end
end
