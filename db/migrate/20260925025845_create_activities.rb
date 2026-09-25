class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.string :title, null: false
      t.text :description
      # Array of [lat, lng] pairs, e.g. [[43.606, -116.204], [43.61, -116.21]].
      # SQLite stores json as TEXT; Rails casts it to/from a Ruby Array.
      t.json :route_coordinates, null: false, default: []

      t.timestamps
    end
  end
end
