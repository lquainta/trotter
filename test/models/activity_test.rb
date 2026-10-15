require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "miles and pace come from the distance and duration" do
    ride = activities(:foothills)

    assert_in_delta 6.0, ride.miles, 0.001
    assert_in_delta 800, ride.pace, 0.01
  end

  test "requires a rider, title, start time, and a positive duration and distance" do
    ride = Activity.new(duration: 0, distance_meters: -1)

    assert_not ride.valid?
    assert_equal %i[ distance_meters duration rider_name started_at title ], ride.errors.attribute_names.sort
  end

  test "newest_first orders by start time" do
    assert_equal %w[ foothills arena hack creek ].map { |name| activities(name) }, Activity.newest_first.to_a
  end
end
