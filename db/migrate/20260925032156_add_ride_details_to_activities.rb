class AddRideDetailsToActivities < ActiveRecord::Migration[8.1]
  def change
    add_reference :activities, :user, null: false, foreign_key: true
    add_column :activities, :started_at, :datetime, null: false
    add_column :activities, :duration, :integer # seconds
    # Calculated from route_coordinates when the ride is saved.
    add_column :activities, :distance_meters, :float, null: false, default: 0.0

    add_index :activities, :started_at
  end
end
