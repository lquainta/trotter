# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Demo riders. Every demo account's password is "password123".
riders = %w[ demo bluegrass_belle rotten_row ].index_with do |username|
  User.find_or_create_by!(username: username) { |user| user.password = "password123" }
end

# Sample rides in different parts of the world, so the feed shows fitBounds framing each route.
[
  {
    user: riders["demo"],
    title: "Arena schooling",
    description: "Flatwork in the indoor arena, so no route today.",
    started_at: 4.days.ago.change(hour: 17, min: 30),
    duration: 50.minutes,
    route_coordinates: []
  },
  {
    user: riders["rotten_row"],
    title: "Rotten Row, Hyde Park",
    description: "A proper London hack down the historic bridleway.",
    started_at: 3.days.ago.change(hour: 9, min: 0),
    duration: 10.minutes + 15.seconds,
    route_coordinates: [
      [ 51.5029, -0.1521 ], [ 51.5032, -0.1570 ], [ 51.5035, -0.1620 ],
      [ 51.5038, -0.1670 ], [ 51.5041, -0.1716 ], [ 51.5045, -0.1757 ]
    ]
  },
  {
    user: riders["bluegrass_belle"],
    title: "Kentucky Horse Park hack",
    description: "Loop around the park grounds.",
    started_at: 2.days.ago.change(hour: 8, min: 15),
    duration: 21.minutes + 40.seconds,
    route_coordinates: [
      [ 38.1462, -84.5219 ], [ 38.1489, -84.5236 ], [ 38.1521, -84.5222 ], [ 38.1537, -84.5184 ],
      [ 38.1522, -84.5143 ], [ 38.1491, -84.5128 ], [ 38.1463, -84.5150 ], [ 38.1462, -84.5219 ]
    ]
  },
  {
    user: riders["demo"],
    title: "Camel's Back foothills loop",
    description: "Easy trot up into the Boise foothills and back.",
    started_at: 1.day.ago.change(hour: 7, min: 10),
    duration: 19.minutes + 50.seconds,
    route_coordinates: [
      [ 43.6352, -116.2031 ], [ 43.6371, -116.2009 ], [ 43.6398, -116.1990 ], [ 43.6425, -116.1962 ],
      [ 43.6446, -116.1929 ], [ 43.6431, -116.1894 ], [ 43.6402, -116.1908 ], [ 43.6377, -116.1948 ],
      [ 43.6358, -116.1990 ], [ 43.6352, -116.2031 ]
    ]
  }
].each do |attributes|
  Activity.find_or_create_by!(title: attributes[:title]) do |activity|
    activity.assign_attributes(attributes)
  end
end
