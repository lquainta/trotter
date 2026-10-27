require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "formats distance, duration, and pace in miles" do
    assert_equal "6.00 mi", format_distance(9656.064)
    assert_equal "1h 20m", format_duration(4800)
    assert_equal "45m", format_duration(2700)
    assert_equal "10m 15s", format_duration(615)
    assert_equal "13:20 /mi", format_pace(9656.064, 4800)
    assert_equal "4.5 mph", format_speed(9656.064, 4800)
    assert_equal "1h 23m", format_duration(4980)
    assert_equal "7:30 /mi", format_pace(1609.344, 450)
  end

  test "formats distance and pace in kilometers" do
    assert_equal "9.66 km", format_distance(9656.064, "km")
    assert_equal "8:17 /km", format_pace(9656.064, 4800, "km")
    assert_equal "7.2 km/h", format_speed(9656.064, 4800, "km")
  end

  test "pace with no distance, and speed with no time" do
    assert_equal "—", format_pace(0, 600)
    assert_equal "—", format_speed(1000, 0)
  end

  test "logged-out visitors get the device theme and miles" do
    assert_equal "system", current_theme
    assert_equal "mi", current_distance_unit
  end

  test "logged-in riders get their own theme and units" do
    Current.session = users(:km_rider).sessions.create!

    assert_equal "dark", current_theme
    assert_equal "km", current_distance_unit
  end
end
