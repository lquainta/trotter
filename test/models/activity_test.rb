require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # One degree of latitude on a sphere the size of the Earth
  METERS_PER_DEGREE = 2 * Math::PI * Activity::EARTH_RADIUS_METERS / 360

  test "requires a rider, title, start time, duration, and route" do
    ride = Activity.new(duration: 0)

    assert_not ride.valid?
    assert_equal %i[ duration route_coordinates started_at title user ], ride.errors.attribute_names.sort
  end

  test "newest_first orders by start time" do
    assert_equal %w[ foothills arena hack creek ].map { |name| activities(name) }, Activity.newest_first.to_a
  end

  test "route_distance adds up the length of each leg" do
    assert_equal 0, Activity.route_distance([])
    assert_equal 0, Activity.route_distance([ [ 43.6, -116.2 ] ])
    assert_in_delta METERS_PER_DEGREE, Activity.route_distance([ [ 0, 0 ], [ 1, 0 ] ]), 0.01
    assert_in_delta 2 * METERS_PER_DEGREE, Activity.route_distance([ [ 0, 0 ], [ 1, 0 ], [ 0, 0 ] ]), 0.01
    # A degree of longitude shrinks away from the equator: cos(60°) = 0.5
    assert_in_delta METERS_PER_DEGREE / 2, Activity.route_distance([ [ 60, 0 ], [ 60, 1 ] ]), 5
  end

  test "saving a ride calculates its distance from the route" do
    ride = new_ride(route_coordinates: [ [ 0, 0 ], [ 0.01, 0 ], [ 0.01, 0.01 ] ])

    assert ride.save
    assert_in_delta 0.02 * METERS_PER_DEGREE, ride.distance_meters, 1
  end

  test "a submitted distance is ignored in favor of the route's" do
    ride = new_ride(distance_meters: 1_000_000)

    ride.save!
    assert_in_delta 0.01 * METERS_PER_DEGREE, ride.distance_meters, 0.01
  end

  test "accepts the route as JSON text from the form and rounds it to six decimal places" do
    ride = new_ride(route_coordinates: "[[43.61500049, -116.2023], [43.62, -116.21]]")

    assert ride.valid?
    assert_equal [ [ 43.615, -116.2023 ], [ 43.62, -116.21 ] ], ride.route_coordinates
  end

  test "rejects routes that aren't map points" do
    [ "not json", "{\"lat\": 1}", "[[1, 2, 3], [4, 5, 6]]", "[[\"43\", \"-116\"], [43, -116]]", "[[91, 0], [0, 0]]", "[[0, 181], [0, 0]]" ].each do |route|
      ride = new_ride(route_coordinates: route)

      assert_not ride.valid?, "#{route} should be invalid"
      assert_equal [ "Route isn't a list of map points" ], ride.errors.full_messages
    end
  end

  test "a route needs at least two points" do
    [ "[]", "[[43.6, -116.2]]" ].each do |route|
      ride = new_ride(route_coordinates: route)

      assert_not ride.valid?
      assert_includes ride.errors[:route_coordinates].first, "at least two points"
    end
  end

  test "a route can't be longer than the maximum number of points" do
    ride = new_ride(route_coordinates: Array.new(Activity::MAX_ROUTE_POINTS + 1) { |i| [ 0, i * 0.0001 ] })

    assert_not ride.valid?
    assert ride.errors.added?(:route_coordinates, "can have at most #{Activity::MAX_ROUTE_POINTS} points")
  end

  test "a route whose points are all in one place has no distance" do
    ride = new_ride(route_coordinates: [ [ 43.6, -116.2 ], [ 43.6, -116.2 ] ])

    assert_not ride.valid?
    assert_equal [ "Distance must be greater than 0" ], ride.errors.full_messages
  end

  test "hours, minutes, and seconds combine into the duration in seconds" do
    ride = new_ride(duration: nil, duration_hours: "1", duration_minutes: "23", duration_seconds: "")

    ride.validate
    assert_equal 4980, ride.duration

    ride = new_ride(duration: nil, duration_hours: "", duration_minutes: "10", duration_seconds: "15")
    ride.validate
    assert_equal 615, ride.duration
  end

  test "an empty duration is an error" do
    ride = new_ride(duration: nil, duration_hours: "", duration_minutes: "", duration_seconds: "")

    assert_not ride.valid?
    assert_equal [ "Duration can't be blank" ], ride.errors.full_messages
  end

  test "minutes and seconds must be under 60" do
    ride = new_ride(duration: nil, duration_hours: "0", duration_minutes: "60", duration_seconds: "-1")

    assert_not ride.valid?
    assert_equal %i[ duration_minutes duration_seconds ], ride.errors.attribute_names
  end

  test "average speed is meters per second" do
    assert_in_delta 2.0117, activities(:foothills).average_speed, 0.0001
  end

  test "rides saved before routes existed keep their distance" do
    ride = activities(:arena)

    ride.update!(title: "Arena flatwork")
    assert_in_delta 1609.344, ride.reload.distance_meters
  end

  test "clearing every duration field on an existing ride is an error, not a silent no-change" do
    ride = activities(:foothills)
    ride.assign_attributes(duration_hours: "", duration_minutes: "", duration_seconds: "")

    assert_not ride.valid?
    assert_includes ride.errors.full_messages, "Duration can't be blank"
  end

  test "editing other details leaves the duration alone" do
    ride = activities(:foothills)

    ride.update!(title: "Foothills, the long way")
    assert_equal 4800, ride.reload.duration
  end

  test "a ride can have JPEG, PNG, WebP, and HEIC photos" do
    ride = new_ride(new_photos: [ photo("trail.jpg"), photo("pasture.png"), photo("iphone.heic") ])

    assert ride.save, ride.errors.full_messages.to_sentence
    assert_equal %w[ image/jpeg image/png image/heic ], ride.photos.map(&:content_type)
  end

  test "files that aren't photos are rejected" do
    ride = new_ride(new_photos: [ photo("notes.txt", "text/plain") ])

    assert_not ride.valid?
    assert_equal [ "Photos must be JPEG, PNG, WebP, or HEIC images" ], ride.errors.full_messages
  end

  test "a ride can have at most 10 photos" do
    ride = new_ride(new_photos: Array.new(11) { photo("trail.jpg") })

    assert_not ride.valid?
    assert_equal [ "Photos can't be more than 10" ], ride.errors.full_messages
  end

  test "photos over 20 MB are rejected" do
    ride = new_ride(new_photos: [ photo("trail.jpg") ])
    ride.validate
    ride.photos.first.blob.byte_size = 21.megabytes

    assert_not ride.valid?
    assert_includes ride.errors.full_messages, "Photos must each be smaller than 20 MB"
  end

  test "adding photos keeps the ones already there, and removing one keeps the rest" do
    ride = new_ride(new_photos: [ photo("trail.jpg") ])
    ride.save!

    ride.update!(new_photos: [ photo("pasture.png") ])
    assert_equal %w[ trail.jpg pasture.png ], ride.reload.photos.map { |p| p.filename.to_s }

    ride.update!(remove_photo_ids: [ ride.photos.first.id.to_s ])
    assert_equal %w[ pasture.png ], ride.reload.photos.map { |p| p.filename.to_s }
  end

  test "another ride's photo can't be removed through this one" do
    other = new_ride(new_photos: [ photo("trail.jpg") ])
    other.save!
    ride = new_ride(new_photos: [ photo("pasture.png") ])
    ride.save!

    ride.update!(remove_photo_ids: [ other.photos.first.id.to_s ])
    assert_equal 1, other.reload.photos.count
    assert_equal 1, ride.reload.photos.count
  end

  test "HEIC photos are converted to WebP for display" do
    ride = new_ride(new_photos: [ photo("iphone.heic") ])
    ride.save!

    variant = ride.photos.first.variant(:preview).processed
    assert_equal "image/webp", variant.image.blob.content_type
  end

  test "deleting a ride deletes its photos" do
    ride = new_ride(new_photos: [ photo("trail.jpg") ])
    ride.save!

    assert_difference -> { ActiveStorage::Attachment.count } => -1, -> { ActiveStorage::Blob.count } => -1 do
      perform_enqueued_jobs { ride.destroy! }
    end
  end

  private
    def photo(name, type = nil)
      Rack::Test::UploadedFile.new(file_fixture(name), type)
    end

    def new_ride(**attributes)
      users(:rider).activities.new(title: "Test ride", started_at: 1.hour.ago, duration: 1800,
        route_coordinates: [ [ 0, 0 ], [ 0.01, 0 ] ], **attributes)
    end
end
