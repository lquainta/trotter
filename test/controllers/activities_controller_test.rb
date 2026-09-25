require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  def ride_params(**overrides)
    { title: "Loop", started_at: "2026-09-24T07:15", duration_hours: "1", duration_minutes: "5", duration_seconds: "0",
      route_coordinates: "[[43.606,-116.204],[43.61,-116.21]]" }.merge(overrides)
  end

  test "the feed is public and shows each ride's stats, with a map only for rides with a route" do
    get activities_url

    assert_response :success
    assert_select "a", text: "Join Trotter"
    assert_select "article", count: Activity.count
    assert_select ".feed-map", count: 1
    assert_select ".feed-map[data-route=?]", activities(:boise_loop).route_coordinates.to_json
    assert_select "##{dom_id(activities(:boise_loop))} dd", text: "0.83 mi"
    assert_select "##{dom_id(activities(:boise_loop))} dd", text: "16:05 /mi"
  end

  test "the feed uses the viewer's distance units" do
    sign_in_as users(:km_rider)
    get activities_url

    assert_select "##{dom_id(activities(:boise_loop))} dd", text: "1.33 km"
    assert_select "##{dom_id(activities(:boise_loop))} dd", text: "6.0 km/h"
  end

  test "logging a ride requires an account" do
    get new_activity_url
    assert_redirected_to new_session_url

    post activities_url, params: { activity: ride_params }
    assert_redirected_to new_session_url
  end

  test "new renders the draw map, undo button, and an empty hidden route" do
    sign_in_as users(:rider)
    get new_activity_url

    assert_response :success
    assert_select "#route-draw-map"
    assert_select "button#undo-last-point[type=button]"
    assert_select "input#route-coordinates-input[type=hidden][value=?]", "[]"
    assert_select "#route-distance[data-distance-unit=mi]"
  end

  test "create saves the ride for the signed-in rider with its time, distance, and photos" do
    sign_in_as users(:rider)

    assert_difference "users(:rider).activities.count", 1 do
      post activities_url, params: { activity: ride_params(photos: [ fixture_file_upload("ride_view.jpg", "image/jpeg") ]) }
    end

    assert_redirected_to activities_url
    ride = users(:rider).activities.last
    assert_equal [ [ 43.606, -116.204 ], [ 43.61, -116.21 ] ], ride.route_coordinates
    assert_equal 3900, ride.duration
    assert_equal Time.zone.local(2026, 9, 24, 7, 15), ride.started_at
    assert_in_delta 656.66, ride.distance_meters, 0.1
    assert_equal [ "ride_view.jpg" ], ride.photos.map { |photo| photo.filename.to_s }
  end

  test "create drops malformed and out-of-range points" do
    sign_in_as users(:rider)
    route = [ [ 43.606, -116.204 ], [ 91, 0 ], [ 0, 181 ], [ 1 ], [ "abc", 1 ], nil, [ "43.61", "-116.21" ] ].to_json

    post activities_url, params: { activity: ride_params(route_coordinates: route) }

    assert_equal [ [ 43.606, -116.204 ], [ 43.61, -116.21 ] ], Activity.last.route_coordinates
  end

  test "create saves an empty route when the payload is not a JSON array" do
    sign_in_as users(:rider)

    [ "not json", "{\"lat\":1}", "", nil ].each do |payload|
      post activities_url, params: { activity: ride_params(route_coordinates: payload) }

      assert_equal [], Activity.last.route_coordinates, "payload: #{payload.inspect}"
    end
  end

  test "create re-renders the form with the submitted route when invalid" do
    sign_in_as users(:rider)

    assert_no_difference "Activity.count" do
      post activities_url, params: { activity: ride_params(title: "", route_coordinates: "[[43.606,-116.204]]") }
    end

    assert_response :unprocessable_content
    assert_select "li", text: "Title can't be blank"
    assert_select "input#route-coordinates-input[value=?]", "[[43.606,-116.204]]"
    assert_select "input[name='activity[duration_minutes]'][value='5']"
  end

  test "create rejects files that aren't photos" do
    sign_in_as users(:rider)

    assert_no_difference "Activity.count" do
      post activities_url, params: { activity: ride_params(photos: [ fixture_file_upload("notes.txt", "text/plain") ]) }
    end

    assert_response :unprocessable_content
    assert_select "li", text: "Photos must be JPEG, PNG, WebP, or HEIC images"
  end
end
