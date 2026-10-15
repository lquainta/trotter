require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "formats distance, duration, and pace" do
    assert_equal "6.00 mi", format_miles(activities(:foothills))
    assert_equal "1h 20m", format_duration(4800)
    assert_equal "45m", format_duration(2700)
    assert_equal "10m 15s", format_duration(615)
    assert_equal "13:20 /mi", format_pace(activities(:foothills))
  end
end
