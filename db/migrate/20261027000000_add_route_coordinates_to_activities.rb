# Each ride's route, drawn on the Log a Ride map: an array of [latitude, longitude] pairs.
# Rides logged before routes existed keep an empty route and their stored distance.
class AddRouteCoordinatesToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :route_coordinates, :json, null: false, default: []
  end
end
