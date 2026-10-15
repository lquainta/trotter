# Sample rides for the feed. Riders can't log their own until Checkpoint 3.
# Safe to run again: each ride is found by its title before it's created.
[
  { rider_name: "demo", title: "Foothills loop", description: "Up Hulls Gulch and back along the ridge. Dusty but gorgeous.",
    started_at: 1.day.ago.change(hour: 7, min: 15), duration: 1.hour + 20.minutes, distance_meters: 9_656 },
  { rider_name: "bluegrass_belle", title: "Morning hack around the farm", description: "Easy walk and trot to start the week.",
    started_at: 2.days.ago.change(hour: 8, min: 0), duration: 45.minutes, distance_meters: 4_828 },
  { rider_name: "rotten_row", title: "Rotten Row, Hyde Park", description: "A proper London hack down the historic bridleway.",
    started_at: 3.days.ago.change(hour: 9, min: 0), duration: 10.minutes + 15.seconds, distance_meters: 1_609 },
  { rider_name: "demo", title: "Arena schooling", description: "Flatwork in the indoor arena.",
    started_at: 4.days.ago.change(hour: 17, min: 30), duration: 50.minutes, distance_meters: 3_219 },
  { rider_name: "bluegrass_belle", title: "Creek crossing practice", description: nil,
    started_at: 6.days.ago.change(hour: 16, min: 45), duration: 1.hour + 5.minutes, distance_meters: 6_437 }
].each do |ride|
  Activity.find_or_create_by!(title: ride[:title]) do |activity|
    activity.assign_attributes(ride.merge(duration: ride[:duration].to_i))
  end
end
