# Sample riders and rides for the feed. Each ride's distance is calculated from its route.
# Every sample account's password is "password123".
# Safe to run again: each rider and ride is found before it's created, and sample rides
# saved before routes existed get their route added.
riders = %w[ demo bluegrass_belle rotten_row ].index_with do |username|
  User.find_or_create_by!(username: username) { |user| user.password = "password123" }
end

new_ride_titles = []

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
    route_coordinates: creek_out + creek_out.reverse.drop(1) },
  # More rides, so search has enough to filter, sort, and page through (10 results per page).
  { user: riders["demo"], title: "Table Rock sunrise", description: "Up to the cross before the heat. Worth the early start.",
    started_at: 8.days.ago.change(hour: 6, min: 0), duration: 1.hour + 45.minutes,
    route_coordinates: [ [ 43.60350, -116.16800 ], [ 43.60150, -116.16100 ], [ 43.59950, -116.15400 ], [ 43.60200, -116.14700 ],
                         [ 43.60420, -116.14250 ], [ 43.60150, -116.14900 ], [ 43.59900, -116.15700 ], [ 43.60350, -116.16800 ] ] },
  { user: riders["rotten_row"], title: "Richmond Park loop", description: "Tamsin Trail all the way round, deer everywhere.",
    started_at: 9.days.ago.change(hour: 10, min: 30), duration: 1.hour + 30.minutes,
    route_coordinates: [ [ 51.45700, -0.27500 ], [ 51.46300, -0.26200 ], [ 51.45900, -0.24800 ], [ 51.44900, -0.24900 ],
                         [ 51.44100, -0.25800 ], [ 51.43900, -0.27400 ], [ 51.44700, -0.28300 ], [ 51.45700, -0.27500 ] ] },
  { user: riders["bluegrass_belle"], title: "Hill sets on the back pasture", description: "Four times up the long hill at a trot.",
    started_at: 10.days.ago.change(hour: 7, min: 30), duration: 40.minutes,
    route_coordinates: [ [ 38.09200, -84.60100 ], [ 38.09600, -84.60300 ], [ 38.09200, -84.60100 ], [ 38.09600, -84.60300 ],
                         [ 38.09200, -84.60100 ], [ 38.09600, -84.60300 ], [ 38.09200, -84.60100 ], [ 38.09600, -84.60300 ],
                         [ 38.09200, -84.60100 ] ] },
  { user: riders["demo"], title: "Barber Park river trail", description: "Flat and easy along the Boise River. Great for a cool-down week.",
    started_at: 12.days.ago.change(hour: 18, min: 0), duration: 55.minutes,
    route_coordinates: [ [ 43.56400, -116.13600 ], [ 43.56700, -116.14500 ], [ 43.57100, -116.15400 ], [ 43.57500, -116.16300 ],
                         [ 43.57100, -116.15400 ], [ 43.56700, -116.14500 ], [ 43.56400, -116.13600 ] ] },
  { user: riders["rotten_row"], title: "Hyde Park evening hack", description: "Quiet hack after work.",
    started_at: 14.days.ago.change(hour: 19, min: 0), duration: 25.minutes,
    route_coordinates: [ [ 51.50480, -0.17520 ], [ 51.50700, -0.17100 ], [ 51.50900, -0.16500 ], [ 51.50700, -0.16000 ],
                         [ 51.50290, -0.15290 ] ] },
  { user: riders["bluegrass_belle"], title: "Trail ride with the Pony Club", description: "Six of us out on the farm trails.",
    started_at: 16.days.ago.change(hour: 13, min: 0), duration: 1.hour + 15.minutes,
    route_coordinates: [ [ 38.08900, -84.59800 ], [ 38.08300, -84.60400 ], [ 38.07800, -84.61200 ], [ 38.08200, -84.62000 ],
                         [ 38.08900, -84.61700 ], [ 38.09300, -84.60800 ], [ 38.08900, -84.59800 ] ] },
  { user: riders["demo"], title: "Polecat Gulch figure eight", description: nil,
    started_at: 19.days.ago.change(hour: 8, min: 45), duration: 1.hour + 10.minutes,
    route_coordinates: [ [ 43.69500, -116.25200 ], [ 43.70100, -116.24600 ], [ 43.70600, -116.25200 ], [ 43.70100, -116.25800 ],
                         [ 43.69500, -116.25200 ], [ 43.68900, -116.24600 ], [ 43.68400, -116.25200 ], [ 43.68900, -116.25800 ],
                         [ 43.69500, -116.25200 ] ] }
].each do |ride|
  activity = Activity.find_or_initialize_by(title: ride[:title])
  new_ride_titles << ride[:title] if activity.new_record?
  activity.assign_attributes(ride.merge(duration: ride[:duration].to_i)) if activity.new_record?
  activity.route_coordinates = ride[:route_coordinates] if activity.route_coordinates.blank?
  activity.save!
end

# Sample horses. A horse is only tied to sample rides when the horse or the ride is first created, so a
# rider who later changes a ride's horse (or deletes the horse) doesn't have it put back on the next deploy.
[
  { user: riders["demo"], name: "Biscuit", breed: "Quarter Horse", color: "Bay", birth_year: 2014,
    notes: "Sure-footed on the foothills trails. Will do anything for a peppermint.",
    rides: [ "Foothills loop", "Arena schooling", "Table Rock sunrise", "Polecat Gulch figure eight" ] },
  { user: riders["bluegrass_belle"], name: "Derby Day", breed: "Thoroughbred", color: "Chestnut", birth_year: 2016,
    notes: "Off-track Thoroughbred, learning to love the trails.",
    rides: [ "Morning hack around the farm", "Creek crossing practice", "Hill sets on the back pasture" ] },
  { user: riders["rotten_row"], name: "Earl Grey", breed: "Irish Draught", color: "Grey", birth_year: 2012,
    notes: nil, rides: [ "Rotten Row, Hyde Park", "Richmond Park loop", "Hyde Park evening hack" ] }
].each do |sample|
  horse = sample[:user].horses.find_or_initialize_by(name: sample[:name])
  titles = horse.new_record? ? sample[:rides] : sample[:rides] & new_ride_titles
  horse.update!(sample.except(:user, :rides)) if horse.new_record?
  sample[:user].activities.where(title: titles, horse_id: nil).update_all(horse_id: horse.id)
end
