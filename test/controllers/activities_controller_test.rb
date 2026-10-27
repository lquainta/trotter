require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  ROUTE = [ [ 43.615, -116.2023 ], [ 43.625, -116.2023 ] ].freeze

  test "the feed lists every ride, newest first, with its stats" do
    get activities_path

    assert_response :success
    assert_select "article", Activity.count
    assert_select "article:first-of-type h2", "Foothills loop"
    assert_select "##{dom_id(activities(:foothills))} dd", "6.00 mi"
    assert_select "##{dom_id(activities(:foothills))} dd", "13:20 /mi"
    assert_select "##{dom_id(activities(:foothills))} dd", "4.5 mph"
  end

  test "the feed links each ride to its rider and uses the viewer's units" do
    sign_in_as users(:km_rider)
    get activities_path

    assert_select "##{dom_id(activities(:foothills))} a[href=?]", user_path(users(:rider)), text: "rider"
    assert_select "##{dom_id(activities(:foothills))} dd", "9.66 km"
    assert_select "##{dom_id(activities(:foothills))} dd", "8:17 /km"
    assert_select "##{dom_id(activities(:foothills))} dd", "7.2 km/h"
  end

  test "the feed draws a map for each ride that has a route" do
    get activities_path

    assert_select "[data-controller=route-map]", 1
    assert_select "##{dom_id(activities(:foothills))} [data-controller=route-map][data-route-map-points-value=?]",
      activities(:foothills).route_coordinates.to_json
  end

  test "the feed shows a message when there are no rides" do
    Activity.delete_all
    get activities_path

    assert_select "article", 0
    assert_select "p", "No rides yet."
  end

  test "logging a ride requires an account" do
    get new_activity_path
    assert_redirected_to new_session_path

    assert_no_difference "Activity.count" do
      post activities_path, params: { activity: ride_params }
    end
    assert_redirected_to new_session_path
  end

  test "the Log a Ride form has the map, its buttons, and the ride's fields" do
    sign_in_as users(:km_rider)
    get new_activity_path

    assert_response :success
    assert_select "[data-controller=route-editor][data-route-editor-unit-value=km]" do
      assert_select "[data-route-editor-target=map]"
      assert_select "input[type=hidden][name=?][value='[]']", "activity[route_coordinates]"
      assert_select "button", "Undo last point"
      assert_select "button", "Clear route"
      assert_select "[data-route-editor-target=distance]", "0.00 km"
    end
    assert_select "input[name=?]", "activity[title]"
    assert_select "input[type=datetime-local][name=?]", "activity[started_at]"
    %w[ hours minutes seconds ].each { |part| assert_select "input[type=number][name=?]", "activity[duration_#{part}]" }
  end

  test "logging a ride saves it to your account with the distance from its route" do
    sign_in_as users(:newcomer)

    assert_difference "users(:newcomer).activities.count" do
      post activities_path, params: { activity: ride_params }
    end
    assert_redirected_to activities_path
    assert_equal "Ride logged.", flash[:notice]

    ride = users(:newcomer).activities.last
    assert_equal "Evening loop", ride.title
    assert_equal ROUTE, ride.route_coordinates
    assert_equal 1.hour + 2.minutes + 3.seconds, ride.duration
    assert_in_delta 1112, ride.distance_meters, 1
  end

  test "you can't log a ride for someone else" do
    sign_in_as users(:newcomer)
    post activities_path, params: { activity: ride_params.merge(user_id: users(:rider).id) }

    assert_equal users(:newcomer), Activity.order(:id).last.user
  end

  test "a route that isn't JSON shows an error instead of crashing" do
    sign_in_as users(:rider)

    [ "not json", "{", "[[1, 2], \"x\"]", "null" ].each do |route|
      assert_no_difference "Activity.count" do
        post activities_path, params: { activity: ride_params.merge(route_coordinates: route) }
      end
      assert_response :unprocessable_content
      assert_select "li", "Route isn't a list of map points"
    end
  end

  test "a missing route, title, or duration shows errors and keeps what was entered" do
    sign_in_as users(:rider)
    post activities_path, params: { activity: ride_params.merge(title: "", route_coordinates: "[]", duration_hours: "",
                                                                duration_minutes: "", duration_seconds: "") }

    assert_response :unprocessable_content
    assert_select "li", "Title can't be blank"
    assert_select "li", "Duration can't be blank"
    assert_select "li", /Route needs at least two points/
    assert_select "textarea[name=?]", "activity[description]", text: "Slow and steady"
  end

  test "a route sent back with an error is kept so it doesn't have to be redrawn" do
    sign_in_as users(:rider)
    post activities_path, params: { activity: ride_params.merge(title: "") }

    assert_response :unprocessable_content
    assert_select "input[name=?][value=?]", "activity[route_coordinates]", ROUTE.to_json
  end

  private
    def ride_params
      { title: "Evening loop", description: "Slow and steady", started_at: "2026-10-26T18:30",
        duration_hours: "1", duration_minutes: "2", duration_seconds: "3", route_coordinates: ROUTE.to_json }
    end
end
