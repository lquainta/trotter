require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "formats distance, duration, and pace in miles" do
    assert_equal "6.00 mi", format_distance(9656.064)
    assert_equal "1h 20m", format_duration(4800)
    assert_equal "45m", format_duration(2700)
    assert_equal "10m 15s", format_duration(615)
    assert_equal "13:20 /mi", format_pace(9656.064, 4800)
  end

  test "formats distance and pace in kilometers" do
    assert_equal "9.66 km", format_distance(9656.064, "km")
    assert_equal "8:17 /km", format_pace(9656.064, 4800, "km")
  end

  test "pace with no distance" do
    assert_equal "—", format_pace(0, 600)
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
