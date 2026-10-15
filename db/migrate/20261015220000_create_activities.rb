class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.string :rider_name, null: false
      t.string :title, null: false
      t.text :description
      t.datetime :started_at, null: false
      t.integer :duration, null: false
      t.float :distance_meters, null: false

      t.timestamps
    end
    add_index :activities, :started_at
  end
end
