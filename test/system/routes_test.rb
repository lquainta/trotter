require "application_system_test_case"

# Needs network access: Leaflet loads from unpkg and tiles from OpenStreetMap.
class RoutesTest < ApplicationSystemTestCase
  setup { log_in_as users(:rider) }

  test "logging a ride with a drawn route, a duration, and a photo" do
    visit new_activity_url
    draw_map = find("#route-draw-map.leaflet-container")

    click_map draw_map, [ [ 80, 90 ], [ 150, 130 ], [ 220, 100 ] ]
    assert_equal 3, drawn_route.size
    assert_selector "#route-draw-map path[stroke='red'][fill='none']", count: 1

    click_on "Undo Last Point"
    assert_equal 2, drawn_route.size
    live_distance = find("#route-distance").text
    assert_match(/\A\d+\.\d\d mi\z/, live_distance)

    fill_in "Title", with: "Foothills trot"
    fill_in "activity[duration_minutes]", with: "20"
    attach_file "Photos", file_fixture("ride_view.jpg")
    click_on "Save Ride"

    assert_text "Ride saved!"
    card = find("article", text: "Foothills trot")
    assert_equal 2, JSON.parse(card.find(".feed-map")["data-route"]).size
    card.assert_selector ".feed-map path[stroke='blue']", count: 1
    card.assert_selector "dd", text: live_distance # The server's distance matches the form's live one
    card.assert_selector "dd", text: "20m 0s"
    assert_image_loaded card.find("img[alt='Photo from Foothills trot']")
  end

  test "a failed save keeps the drawn route" do
    visit new_activity_url
    click_map find("#route-draw-map.leaflet-container"), [ [ 80, 90 ], [ 150, 130 ] ]

    fill_in "Title", with: "No time given"
    click_on "Save Ride"

    assert_text "Duration can't be blank"
    assert_selector "#route-draw-map path[stroke='red'][fill='none']", count: 1
    assert_equal 2, drawn_route.size
  end

  test "maps survive Turbo navigation, Back, and Forward without errors" do
    feed_maps = Activity.all.count { |activity| activity.route_coordinates.any? }

    visit activities_url
    page.execute_script <<~JS
      window.mapErrors = []
      window.addEventListener("error", (event) => window.mapErrors.push(event.message))
    JS
    assert_healthy_maps ".feed-map", count: feed_maps

    click_on "Log a Ride"
    assert_healthy_maps "#route-draw-map", count: 1

    click_on "Feed"
    assert_healthy_maps ".feed-map", count: feed_maps

    page.go_back
    assert_healthy_maps "#route-draw-map", count: 1

    page.go_back
    assert_healthy_maps ".feed-map", count: feed_maps

    page.go_forward
    assert_healthy_maps "#route-draw-map", count: 1

    # Same JS context the whole time means Turbo never did a full page load.
    assert_equal [], page.evaluate_script("window.mapErrors")
  end

  private
    def click_map(map, offsets)
      offsets.each { |x, y| map.click(x: x, y: y) }
    end

    def drawn_route
      JSON.parse(find("#route-coordinates-input", visible: false).value)
    end

    def assert_image_loaded(image)
      page.document.synchronize(10, errors: [ Capybara::ExpectationNotMet ]) do
        loaded = page.evaluate_script("arguments[0].complete && arguments[0].naturalWidth > 0", image)
        raise Capybara::ExpectationNotMet, "photo didn't load" unless loaded
      end
    end

    # Waits for Turbo to finish the visit (it may show a cached preview first), then checks that each
    # container holds exactly one initialized Leaflet map, with no leftover panes from Turbo's cached copy.
    def assert_healthy_maps(selector, count:)
      assert_selector "#{selector}.leaflet-container", count: count
      assert_no_selector "html[aria-busy]"

      healthy = page.evaluate_script(<<~JS, selector)
        [ ...document.querySelectorAll(arguments[0]) ].every((container) =>
          container._leaflet_id !== undefined && container.querySelectorAll(".leaflet-map-pane").length === 1)
      JS
      assert healthy, "expected every #{selector} to hold exactly one initialized map"
    end
end
