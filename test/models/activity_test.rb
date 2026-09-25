require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  def build_activity(**attributes)
    users(:rider).activities.build(title: "Loop", started_at: Time.current, duration: 600, **attributes)
  end

  test "route_coordinates round-trips through the json column as an Array" do
    activity = build_activity(route_coordinates: [ [ 43.606, -116.204 ], [ 43.61, -116.21 ] ])
    activity.save!

    assert_equal [ [ 43.606, -116.204 ], [ 43.61, -116.21 ] ], activity.reload.route_coordinates
  end

  test "route_coordinates defaults to an empty route" do
    assert_equal [], Activity.new.route_coordinates
    assert build_activity.valid?
  end

  test "rejects route_coordinates that are not lat/lng pairs" do
    [ [ [ 43.6 ] ], [ [ "43.6", "-116.2" ] ], "[[43.6,-116.2]]", { "lat" => 43.6 } ].each do |bad_route|
      activity = build_activity(route_coordinates: bad_route)

      assert_not activity.valid?, "expected #{bad_route.inspect} to be invalid"
      assert_includes activity.errors[:route_coordinates], "must be a list of [lat, lng] pairs"
    end
  end

  test "calculates the route distance when saved" do
    activity = build_activity(route_coordinates: [ [ 0, 0 ], [ 1, 0 ], [ 1, 1 ] ])
    activity.save!

    # One degree of latitude, then one degree of longitude at 1°N, on a 6,371 km sphere
    assert_in_delta 111_194.93 + 111_177.99, activity.distance_meters, 0.5
  end

  test "a ride without a route has no distance" do
    activity = build_activity
    activity.save!

    assert_equal 0, activity.distance_meters
  end

  test "requires a title, a start time, and a duration" do
    activity = Activity.new(user: users(:rider))

    assert_not activity.valid?
    assert_includes activity.errors[:title], "can't be blank"
    assert_includes activity.errors[:started_at], "can't be blank"
    assert_includes activity.errors[:duration], "can't be blank"
  end

  test "combines the hour, minute, and second fields into duration" do
    activity = build_activity(duration: nil, duration_hours: 1, duration_minutes: 2, duration_seconds: 3)

    assert activity.valid?
    assert_equal 3723, activity.duration
  end

  test "rejects a zero duration and out-of-range minutes" do
    assert_includes build_activity(duration_minutes: 0).tap(&:valid?).errors[:duration], "must be greater than 0"
    assert_includes build_activity(duration_minutes: 75).tap(&:valid?).errors[:duration_minutes], "must be in 0..59"
  end

  test "accepts JPEG and HEIC photos" do
    activity = build_activity
    activity.photos.attach(io: file_fixture("ride_view.jpg").open, filename: "ride_view.jpg")
    activity.photos.attach(io: file_fixture("ride_view.heic").open, filename: "ride_view.heic")

    assert activity.valid?, activity.errors.full_messages.to_sentence
  end

  test "rejects files that aren't photos" do
    activity = build_activity
    activity.photos.attach(io: file_fixture("notes.txt").open, filename: "notes.txt")

    assert_not activity.valid?
    assert_includes activity.errors[:photos], "must be JPEG, PNG, WebP, or HEIC images"
  end

  test "rejects more than 10 photos" do
    activity = build_activity
    11.times { |i| activity.photos.attach(io: file_fixture("ride_view.jpg").open, filename: "view_#{i}.jpg") }

    assert_not activity.valid?
    assert_includes activity.errors[:photos], "can't be more than 10"
  end

  test "photo variants are WebP, so HEIC uploads display in browsers" do
    activity = build_activity
    activity.photos.attach(io: file_fixture("ride_view.heic").open, filename: "ride_view.heic")
    activity.save!

    preview = activity.photos.first.variant(:preview).processed
    assert_equal "image/webp", preview.image.blob.content_type
  end
end
