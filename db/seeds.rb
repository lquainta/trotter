# Sample riders and rides for the feed. Each ride's distance is calculated from its route.
# Every sample account's password is "password123".
# Safe to run again: each rider and ride is found before it's created, and sample rides
# saved before routes existed get their route added.
riders = %w[ demo bluegrass_belle rotten_row ].index_with do |username|
  User.find_or_create_by!(username: username) { |user| user.password = "password123" }
end

# Laps of an outdoor arena: a 66 m by 24 m rectangle, twelve times around.
arena_corners = [ [ 43.56500, -116.30000 ], [ 43.56560, -116.30000 ], [ 43.56560, -116.29970 ], [ 43.56500, -116.29970 ] ]
creek_out = [ [ 38.10100, -84.60500 ], [ 38.10260, -84.60720 ], [ 38.10450, -84.61100 ], [ 38.10630, -84.61310 ],
              [ 38.10800, -84.61500 ], [ 38.11010, -84.61640 ], [ 38.11200, -84.61750 ] ]

[
  { user: riders["demo"], title: "Foothills loop", description: "Up Hulls Gulch and back along the ridge. Dusty but gorgeous.",
    started_at: 1.day.ago.change(hour: 7, min: 15), duration: 1.hour + 20.minutes,
    route_coordinates: [ [ 43.63420, -116.18620 ], [ 43.63980, -116.18100 ], [ 43.64550, -116.17720 ], [ 43.65120, -116.17300 ],
                         [ 43.65700, -116.17050 ], [ 43.66310, -116.16800 ], [ 43.66650, -116.17450 ], [ 43.66380, -116.18200 ],
                         [ 43.65750, -116.18500 ], [ 43.65200, -116.19050 ], [ 43.64600, -116.19400 ], [ 43.63950, -116.19250 ],
                         [ 43.63420, -116.18620 ] ] },
  { user: riders["bluegrass_belle"], title: "Morning hack around the farm", description: "Easy walk and trot to start the week.",
    started_at: 2.days.ago.change(hour: 8, min: 0), duration: 45.minutes,
    route_coordinates: [ [ 38.08900, -84.59800 ], [ 38.09500, -84.59750 ], [ 38.09850, -84.59000 ], [ 38.09600, -84.58300 ],
                         [ 38.09000, -84.58350 ], [ 38.08650, -84.59050 ], [ 38.08900, -84.59800 ] ] },
  { user: riders["rotten_row"], title: "Rotten Row, Hyde Park", description: "A proper London hack down the historic bridleway.",
    started_at: 3.days.ago.change(hour: 9, min: 0), duration: 10.minutes + 15.seconds,
    route_coordinates: [ [ 51.50290, -0.15290 ], [ 51.50335, -0.15800 ], [ 51.50380, -0.16300 ], [ 51.50420, -0.16800 ],
                         [ 51.50460, -0.17300 ], [ 51.50480, -0.17520 ] ] },
  { user: riders["demo"], title: "Arena schooling", description: "Flatwork in the outdoor arena.",
    started_at: 4.days.ago.change(hour: 17, min: 30), duration: 50.minutes,
    route_coordinates: arena_corners * 12 + [ arena_corners.first ] },
  { user: riders["bluegrass_belle"], title: "Creek crossing practice", description: nil,
    started_at: 6.days.ago.change(hour: 16, min: 45), duration: 1.hour + 5.minutes,
    route_coordinates: creek_out + creek_out.reverse.drop(1) }
].each do |ride|
  activity = Activity.find_or_initialize_by(title: ride[:title])
  activity.assign_attributes(ride.merge(duration: ride[:duration].to_i)) if activity.new_record?
  activity.route_coordinates = ride[:route_coordinates] if activity.route_coordinates.blank?
  activity.save!
end
