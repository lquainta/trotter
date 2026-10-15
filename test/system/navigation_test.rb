require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "getting from the landing page to the feed and back" do
    visit root_url
    assert_selector "h1", text: "Every ride, logged and shared"

    within("header") { click_on "Feed" }
    assert_selector "h1", text: "Feed"
    assert_selector "article", count: Activity.count

    within("footer") { click_on "Home" }
    assert_selector "h1", text: "Every ride, logged and shared"
  end
end
