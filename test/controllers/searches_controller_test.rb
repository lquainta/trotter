require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  test "an empty search shows the prompt and example searches, not every ride" do
    get search_path

    assert_response :success
    assert_select "h1", "Search rides"
    assert_select "form[action=?][method=get][role=search]", search_path
    assert_select "#search-prompt h2", "Set at least one filter to search"
    assert_select "#search-prompt a[href=?]", search_path(photos: "1")
    assert_select "#search-results", count: 0
    assert_select "li[id^=result_activity]", count: 0
  end

  test "submitting the form with every field blank still shows the prompt" do
    get search_path, params: { q: "", rider: "", horse_id: "", min_distance: "", max_distance: "", from: "", to: "",
                               photos: "0", sort: "newest" }

    assert_select "#search-prompt"
    assert_select "li[id^=result_activity]", count: 0
  end

  test "the form has every filter and the sort" do
    get search_path

    %w[ q rider horse_id min_distance max_distance from to photos sort ].each do |name|
      assert_select "[name=?]", name
    end
    assert_select "select[name=horse_id] optgroup[label=?] option[value=?]", "rider's horses", horses(:biscuit).id.to_s, text: "Biscuit"
    assert_select "select[name=sort] option", 4
  end

  test "a search lists matching rides with a route outline, and keeps the filters in the form" do
    get search_path, params: { rider: "rider", sort: "longest" }

    assert_select "#search-results h2", "Showing 1–2 of 2 rides"
    assert_select "#search-results li", 2
    assert_select "li#result_#{dom_id(activities(:foothills))} a[href=?]", activity_path(activities(:foothills)), text: "Foothills loop"
    assert_select "li#result_#{dom_id(activities(:foothills))} svg[aria-label=?] polyline", "Route outline of Foothills loop"
    assert_select "li#result_#{dom_id(activities(:foothills))}", text: /on Biscuit/
    assert_select "#search-results li:first-child h3", "Foothills loop"
    assert_select "input[name=rider][value=rider]"
    assert_select "select[name=sort] option[selected][value=longest]"
  end

  test "a search with no matches says so" do
    get search_path, params: { q: "nothing like this" }

    assert_select "#search-results", "No rides match that search."
  end

  test "distances are in the viewer's units" do
    sign_in_as users(:km_rider)
    get search_path, params: { max_distance: "2" }

    assert_select "legend", "Distance (km)"
    assert_select "#search-results li", 1
    assert_select "li#result_#{dom_id(activities(:arena))}", text: /1\.61 km/
  end

  test "results come 10 per page, with Previous and Next links that keep the search" do
    12.times do |index|
      users(:newcomer).activities.create!(title: "Lap #{index}", started_at: index.hours.ago, duration: 600,
                                          route_coordinates: [ [ 43.6, -116.2 ], [ 43.61, -116.2 ] ])
    end

    get search_path, params: { rider: "newcomer" }
    assert_select "#search-results li", 10
    assert_select "#search-results h2", "Showing 1–10 of 12 rides"
    assert_select "a[rel=next][href=?]", search_path(rider: "newcomer", page: 2)
    assert_select "a[rel=prev]", count: 0

    get search_path, params: { rider: "newcomer", page: 2 }
    assert_select "#search-results li", 2
    assert_select "#search-results h2", "Showing 11–12 of 12 rides"
    assert_select "a[rel=prev][href=?]", search_path(rider: "newcomer", page: 1)
    assert_select "a[rel=next]", count: 0
  end

  test "a page past the end says so instead of erroring" do
    get search_path, params: { rider: "rider", page: 9 }

    assert_response :success
    assert_select "#search-results h2", /No more results/
  end

  test "odd input is ignored instead of erroring or reaching the SQL" do
    get search_path, params: { q: "'; DROP TABLE activities; --", min_distance: "abc", from: "not-a-date", horse_id: "1 OR 1=1" }

    assert_response :success
    assert_select "#search-results", "No rides match that search."
    assert_equal 4, Activity.count
  end
end
