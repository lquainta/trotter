require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "a profile shows the rider's rides and totals" do
    get user_path(users(:rider))

    assert_response :success
    assert_select "h1", "rider"
    assert_select "article", count: users(:rider).activities.count
    assert_select "dd", text: "0.83 mi"
    assert_select "a", text: "Settings", count: 0
  end

  test "your own profile links to settings" do
    sign_in_as users(:rider)
    get user_path(users(:rider))

    assert_select "h2", "Your rides"
    assert_select "a[href=?]", settings_path, text: "Settings"
  end

  test "an unknown username is a 404" do
    get user_path("nobody_here")

    assert_response :not_found
  end
end
