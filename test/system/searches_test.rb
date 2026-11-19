require "application_system_test_case"

class SearchesTest < ApplicationSystemTestCase
  test "running several searches that return different rides, then an empty one" do
    visit root_url
    within("header") { click_on "Search" }
    assert_selector "h1", text: "Search rides"
    assert_text "Set at least one filter to search"
    assert_no_selector "#search-results"

    fill_in "Rider", with: "rider"
    click_button "Search"
    assert_text "Showing 1–2 of 2 rides"
    assert_selector "#search-results li", text: "Foothills loop"
    assert_selector "#search-results li", text: "Creek crossing practice"
    assert_current_path(/rider=rider/)

    select "Biscuit", from: "Horse"
    click_button "Search"
    assert_text "Showing 1–1 of 1 ride"
    assert_no_selector "#search-results li", text: "Creek crossing practice"

    click_on "Clear"
    fill_in "Minimum distance", with: "2"
    select "Longest first", from: "Sort"
    click_button "Search"
    assert_text "Showing 1–3 of 3 rides"
    assert_equal [ "Foothills loop", "Creek crossing practice", "Morning hack" ], all("#search-results h3").map(&:text)

    click_on "Clear"
    click_button "Search"
    assert_text "Set at least one filter to search"
    assert_no_selector "#search-results"

    click_on "Rides mentioning “hack”"
    assert_selector "#search-results li", count: 1, text: "Morning hack"
    click_on "Morning hack"
    assert_selector "h1", text: "Morning hack"
  end
end
