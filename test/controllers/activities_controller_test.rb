require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

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

  test "each feed card links to the ride's page" do
    get activities_path

    assert_select "##{dom_id(activities(:foothills))} h2 a[href=?]", activity_path(activities(:foothills))
  end

  test "the ride page shows the ride, its stats, and a large map anyone can explore" do
    get activity_path(activities(:foothills))

    assert_response :success
    assert_select "h1", "Foothills loop"
    assert_select "a[href=?]", user_path(users(:rider)), text: "rider"
    assert_select "dd", "6.00 mi"
    assert_select "dd", "13:20 /mi"
    assert_select "p", "Up the gulch and back along the ridge."
    assert_select "[data-controller=route-map][data-route-map-interactive-value=true][data-route-map-points-value=?]",
      activities(:foothills).route_coordinates.to_json
    assert_select "#photos", text: /No photos from this ride/
  end

  test "the ride page has a gallery of the ride's photos" do
    ride = activities(:foothills)
    ride.update!(new_photos: [ photo("trail.jpg"), photo("pasture.png") ])

    get activity_path(ride)

    assert_select "#photos li img", 2
    assert_select "#photos a[target=_blank]", 2
    get activities_path
    assert_select "##{dom_id(ride)} ul[aria-label=Photos] img", 2
  end

  test "only the owner sees Edit and Delete on the ride page" do
    ride = activities(:foothills)

    get activity_path(ride)
    assert_select "a[href=?]", edit_activity_path(ride), count: 0
    assert_select "form[action=?] button", activity_path(ride), count: 0

    sign_in_as users(:km_rider)
    get activity_path(ride)
    assert_select "a[href=?]", edit_activity_path(ride), count: 0

    sign_in_as users(:rider)
    get activity_path(ride)
    assert_select "a[href=?]", edit_activity_path(ride), text: "Edit"
    assert_select "form[action=?] input[name=_method][value=delete]", activity_path(ride)
  end

  test "a ride that doesn't exist is not found" do
    get activity_path(id: 0)
    assert_response :not_found
  end

  test "the Edit Ride form is filled in with the ride's details" do
    ride = activities(:foothills)
    ride.update!(new_photos: [ photo("trail.jpg") ])
    sign_in_as users(:rider)

    get edit_activity_path(ride)

    assert_response :success
    assert_select "input[name=?][value=?]", "activity[title]", "Foothills loop"
    assert_select "input[name=?][value=?]", "activity[route_coordinates]", ride.route_coordinates.to_json
    assert_select "input[name=?][value='1']", "activity[duration_hours]"
    assert_select "input[name=?][value='20']", "activity[duration_minutes]"
    assert_select "input[name=?][value='0']", "activity[duration_seconds]"
    assert_select "input[type=checkbox][name=?][value=?]", "activity[remove_photo_ids][]", ride.photos.first.id.to_s
    assert_select "input[type=file][multiple][name=?]", "activity[new_photos][]"
    assert_select "input[type=submit][value=?]", "Save changes"
    assert_select "form[action=?] button", activity_path(ride), text: "Delete ride"
  end

  test "editing a ride saves the new details and route" do
    ride = activities(:foothills)
    sign_in_as users(:rider)

    patch activity_path(ride), params: { activity: ride_params.merge(title: "Foothills, reversed") }

    assert_redirected_to activity_path(ride)
    assert_equal "Ride updated.", flash[:notice]
    ride.reload
    assert_equal "Foothills, reversed", ride.title
    assert_equal ROUTE, ride.route_coordinates
    assert_in_delta 1112, ride.distance_meters, 1
    assert_equal 3723, ride.duration
  end

  test "editing a ride adds new photos and removes the checked ones" do
    ride = activities(:foothills)
    ride.update!(new_photos: [ photo("trail.jpg"), photo("pasture.png") ])
    trail = ride.photos.find { |p| p.filename == "trail.jpg" }
    sign_in_as users(:rider)

    perform_enqueued_jobs do
      patch activity_path(ride), params: { activity: { title: "With photos", remove_photo_ids: [ trail.id.to_s ],
                                                       new_photos: [ photo("iphone.heic") ] } }
    end

    assert_redirected_to activity_path(ride)
    assert_equal %w[ pasture.png iphone.heic ], ride.reload.photos.map { |p| p.filename.to_s }
    assert_not ActiveStorage::Blob.exists?(trail.blob_id), "the removed photo's file should be deleted"
  end

  test "an edit with errors shows them and saves nothing" do
    ride = activities(:foothills)
    ride.update!(new_photos: [ photo("trail.jpg") ])
    sign_in_as users(:rider)

    patch activity_path(ride), params: { activity: { title: "", remove_photo_ids: [ ride.photos.first.id.to_s ],
                                                     new_photos: [ photo("notes.txt", "text/plain") ] } }

    assert_response :unprocessable_content
    assert_select "li", "Title can't be blank"
    assert_select "li", "Photos must be JPEG, PNG, WebP, or HEIC images"
    assert_select "input[type=checkbox][name=?][checked]", "activity[remove_photo_ids][]"
    assert_equal "Foothills loop", ride.reload.title
    assert_equal 1, ride.photos.count
  end

  test "deleting a ride deletes it and its photos" do
    ride = activities(:foothills)
    ride.update!(new_photos: [ photo("trail.jpg") ])
    sign_in_as users(:rider)

    assert_difference -> { Activity.count } => -1, -> { ActiveStorage::Blob.count } => -1 do
      perform_enqueued_jobs { delete activity_path(ride) }
    end
    assert_redirected_to activities_path
    assert_equal "Ride deleted.", flash[:notice]
  end

  test "another rider can't edit, update, or delete your ride" do
    ride = activities(:foothills)
    sign_in_as users(:km_rider)

    get edit_activity_path(ride)
    assert_response :not_found

    patch activity_path(ride), params: { activity: { title: "Hijacked" } }
    assert_response :not_found
    assert_equal "Foothills loop", ride.reload.title

    assert_no_difference "Activity.count" do
      delete activity_path(ride)
    end
    assert_response :not_found
  end

  test "logged-out visitors are sent to log in before editing or deleting" do
    ride = activities(:foothills)

    get edit_activity_path(ride)
    assert_redirected_to new_session_path
    patch activity_path(ride), params: { activity: { title: "Hijacked" } }
    assert_redirected_to new_session_path
    assert_no_difference("Activity.count") { delete activity_path(ride) }
    assert_redirected_to new_session_path
  end

  test "photos can be added when logging a ride" do
    sign_in_as users(:newcomer)

    post activities_path, params: { activity: ride_params.merge(new_photos: [ photo("trail.jpg") ]) }

    assert_equal [ "trail.jpg" ], users(:newcomer).activities.last.photos.map { |p| p.filename.to_s }
  end

  private
    def photo(name, type = nil)
      Rack::Test::UploadedFile.new(file_fixture(name), type)
    end

    def ride_params
      { title: "Evening loop", description: "Slow and steady", started_at: "2026-10-26T18:30",
        duration_hours: "1", duration_minutes: "2", duration_seconds: "3", route_coordinates: ROUTE.to_json }
    end
end
