require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  test "format_distance in miles and kilometers" do
    assert_equal "1.00 mi", format_distance(1609.344, "mi")
    assert_equal "1.61 km", format_distance(1609.344, "km")
    assert_equal "—", format_distance(0, "mi")
  end

  test "format_duration" do
    assert_equal "1h 23m", format_duration(4980)
    assert_equal "12m 34s", format_duration(754)
    assert_equal "42s", format_duration(42)
    assert_equal "—", format_duration(nil)
  end

  test "format_pace is time per mile or km" do
    assert_equal "7:30 /mi", format_pace(1609.344, 450, "mi")
    assert_equal "4:40 /km", format_pace(1609.344, 450, "km")
    assert_equal "—", format_pace(0, 450, "mi")
    assert_equal "—", format_pace(1609.344, nil, "mi")
  end

  test "format_speed" do
    assert_equal "8.0 mph", format_speed(1609.344, 450, "mi")
    assert_equal "12.9 km/h", format_speed(1609.344, 450, "km")
    assert_equal "—", format_speed(1609.344, 0, "mi")
  end

  test "format_start_time says Today and Yesterday for recent rides" do
    travel_to Time.zone.local(2026, 9, 24, 20, 0) do
      assert_equal "Today at 7:15 AM", format_start_time(Time.zone.local(2026, 9, 24, 7, 15))
      assert_equal "Yesterday at 6:02 PM", format_start_time(Time.zone.local(2026, 9, 23, 18, 2))
      assert_equal "September 3, 2026 at 9:00 AM", format_start_time(Time.zone.local(2026, 9, 3, 9, 0))
    end
  end

  test "current_distance_unit comes from the signed-in user, defaulting to miles" do
    assert_equal "mi", current_distance_unit

    Current.session = users(:km_rider).sessions.create!
    assert_equal "km", current_distance_unit
  end
end
