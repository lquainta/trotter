require "application_system_test_case"

class ActivitiesTest < ApplicationSystemTestCase
  test "logging a ride by drawing its route on the map" do
    log_in_as users(:newcomer)
    within("header") { click_on "Log a Ride" }

    assert_selector "h1", text: "Log a ride"
    assert_route_points 0
    assert_button "Undo last point", disabled: true
    assert_distance "0.00 mi"

    click_map 0, 0
    click_map 120, 0
    click_map 120, 90
    assert_route_points 3
    assert_no_distance "0.00 mi"

    click_on "Undo last point"
    assert_route_points 2

    click_on "Clear route"
    assert_route_points 0
    assert_distance "0.00 mi"
    assert_button "Clear route", disabled: true

    click_map(-150, -80)
    click_map 0, 0
    click_map 150, 80
    assert_route_points 3
    drawn_distance = find("[data-route-editor-target=distance]").text

    fill_in "Title", with: "Map test ride"
    fill_in "Description", with: "Three clicks long."
    fill_in "Hours", with: "1"
    fill_in "Minutes", with: "5"
    click_on "Log ride"

    assert_text "Ride logged."
    assert_selector "h1", text: "Feed"
    ride = Activity.find_by!(title: "Map test ride")
    assert_equal 3, ride.route_coordinates.size
    assert_equal 65.minutes, ride.duration

    within("article", text: "Map test ride") do
      assert_text drawn_distance
      assert_text "1h 5m"
      assert_selector ".leaflet-overlay-pane path", count: 3 # the route's line and its start and end dots
    end
  end

  test "a form with errors keeps the drawn route" do
    log_in_as users(:rider)
    visit new_activity_url

    click_map 0, 0
    click_map 100, 100
    fill_in "Title", with: "No duration"
    click_on "Log ride"

    assert_text "Duration can't be blank"
    assert_route_points 2
    assert_button "Undo last point", disabled: false
  end

  test "feed maps frame their route and survive Back and Forward" do
    visit activities_url
    map = "##{dom_id(activities(:foothills))} .leaflet-container"
    assert_selector "#{map} .leaflet-map-pane", count: 1
    assert_route_is_framed map

    within("header") { click_on "Home" }
    assert_selector "h1", text: "Every ride, logged and shared"

    # Back restores the feed from Turbo's cache, which still holds a copy of the old map.
    page.go_back
    assert_selector "h1", text: "Feed"
    assert_selector "#{map} .leaflet-map-pane", count: 1
    assert_route_is_framed map

    page.go_forward
    assert_selector "h1", text: "Every ride, logged and shared"
    page.go_back
    assert_selector "#{map} .leaflet-map-pane", count: 1
  end

  test "editing a ride: redraw the route, add a photo, and remove one" do
    ride = activities(:foothills)
    ride.update!(new_photos: [ Rack::Test::UploadedFile.new(file_fixture("trail.jpg")) ])
    log_in_as users(:rider)

    visit activity_url(ride)
    assert_selector "h1", text: "Foothills loop"
    assert_selector "#photos img", count: 1
    assert_selector ".leaflet-control-zoom" # the ride page's map can be zoomed
    click_on "Edit"

    assert_selector "h1", text: "Edit ride"
    assert_route_points 4
    click_on "Undo last point"
    assert_route_points 3

    fill_in "Title", with: "Foothills, short version"
    check "Remove"
    attach_file "Add photos", [ file_fixture("pasture.png"), file_fixture("iphone.heic") ]
    click_on "Save changes"

    assert_text "Ride updated."
    assert_selector "h1", text: "Foothills, short version"
    assert_selector "#photos img", count: 2
    assert_equal %w[ pasture.png iphone.heic ], ride.reload.photos.map { |p| p.filename.to_s }
    assert_equal 3, ride.route_coordinates.size
    # Each photo, HEIC included, is shown as a WebP that the browser can display.
    all("#photos img").each do |img|
      assert page.evaluate_script("arguments[0].complete && arguments[0].naturalWidth > 0", img), "photo should load"
    end
  end

  test "deleting a ride from its page" do
    log_in_as users(:rider)
    visit activity_url(activities(:creek))

    accept_confirm { click_on "Delete" }

    assert_text "Ride deleted."
    assert_selector "h1", text: "Feed"
    assert_no_text "Creek crossing practice"
  end

  test "another rider's edit page is not found" do
    log_in_as users(:km_rider)
    visit activity_url(activities(:foothills))
    assert_no_link "Edit"

    visit edit_activity_url(activities(:foothills))
    assert_no_selector "h1", text: "Edit ride"
    assert_no_field "Title"
  end

  private
    # Offsets are from the middle of the map.
    def click_map(x, y)
      find("[data-route-editor-target=map]").click(x: x, y: y)
    end

    def assert_route_points(count)
      assert_equal count, JSON.parse(find("input[name='activity[route_coordinates]']", visible: false).value).size
    end

    def assert_distance(text)
      assert_selector "[data-route-editor-target=distance]", text: text
    end

    def assert_no_distance(text)
      assert_no_selector "[data-route-editor-target=distance]", text: text
    end

    # The route's line is drawn inside the visible part of the map.
    def assert_route_is_framed(map)
      line = find("#{map} .leaflet-overlay-pane path", match: :first) # the route's line comes before its start and end dots
      inside = page.evaluate_script(<<~JS, line)
        (() => {
          const box = arguments[0].getBoundingClientRect()
          const frame = arguments[0].closest(".leaflet-container").getBoundingClientRect()
          return box.width > 20 && box.left >= frame.left && box.right <= frame.right &&
                 box.top >= frame.top && box.bottom <= frame.bottom
        })()
      JS
      assert inside, "The route should fill part of the map and stay inside it"
    end
end
