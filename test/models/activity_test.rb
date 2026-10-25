require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "requires a rider, title, start time, and a positive duration and distance" do
    ride = Activity.new(duration: 0, distance_meters: -1)

    assert_not ride.valid?
    assert_equal %i[ distance_meters duration started_at title user ], ride.errors.attribute_names.sort
  end

  test "newest_first orders by start time" do
    assert_equal %w[ foothills arena hack creek ].map { |name| activities(name) }, Activity.newest_first.to_a
  end
end
