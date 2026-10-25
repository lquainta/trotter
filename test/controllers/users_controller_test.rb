require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "a profile shows the rider's rides and totals" do
    get user_path(users(:rider))

    assert_response :success
    assert_select "h1", "rider"
    assert_select "article", count: 2
    assert_select "dd", text: "2"
    assert_select "dd", text: "10.00 mi"
    assert_select "dd", text: "2h 25m"
    assert_select "a", text: "Settings", count: 0
  end

  test "totals use the viewer's units" do
    sign_in_as users(:km_rider)
    get user_path(users(:rider))

    assert_select "dd", text: "16.09 km"
  end

  test "your own profile links to settings" do
    sign_in_as users(:rider)
    get user_path(users(:rider))

    assert_select "h2", "Your rides"
    assert_select "a[href=?]", settings_path, text: "Settings"
  end

  test "a rider with no rides" do
    get user_path(users(:newcomer))

    assert_select "dd", text: "0"
    assert_select "p", text: "newcomer hasn't logged any rides yet."
  end

  test "an unknown username is a 404" do
    get user_path("nobody_here")

    assert_response :not_found
  end
end
