require "application_system_test_case"

class HorsesTest < ApplicationSystemTestCase
  test "add a horse, log two rides on it, check its totals, then delete it and keep the rides" do
    log_in_as users(:newcomer)
    find("a[title='Your profile']").click
    click_on "Add a horse"

    fill_in "Name", with: "Juniper"
    fill_in "Breed", with: "Arabian"
    fill_in "Color", with: "Grey"
    fill_in "Birth year", with: Date.current.year - 8
    attach_file "Add a photo", file_fixture("iphone.heic")
    click_on "Add horse"

    assert_text "Juniper added."
    assert_selector "h1", text: "Juniper"
    assert_text "Arabian · Grey · 8 years old"
    assert_selector "img[alt='Photo of Juniper']"
    within("#workload-all-time") { assert_selector "dd", text: "0", match: :first }

    log_ride "Morning lap", minutes: 30
    log_ride "Evening lap", minutes: 45

    within("header") { find("a[title='Your profile']").click }
    click_on "Juniper", match: :first # the horse card comes before the rides that mention it
    within("#workload-all-time") do
      assert_selector "dd", text: "2", match: :first
      assert_text "1h 15m"
    end
    within("#workload-this-week") { assert_text "1h 15m" }
    assert_selector "article", count: 2

    accept_confirm { click_on "Delete Juniper" }
    assert_text "Juniper deleted."
    assert_no_link "Juniper"
    assert_selector "article", text: "Morning lap"
    assert_selector "article", text: "Evening lap"
    assert_equal 2, users(:newcomer).activities.where(horse: nil).count
  end

  test "another rider's horse can't be edited" do
    log_in_as users(:km_rider)
    visit horse_url(horses(:biscuit))
    assert_selector "h1", text: "Biscuit"
    assert_no_link "Edit"

    visit edit_horse_url(horses(:biscuit))
    assert_no_field "Name"
  end

  private
    def log_ride(title, minutes:)
      within("header") { click_on "Log a Ride" }
      map = find("[data-route-editor-target=map]")
      map.click(x: -60, y: 0)
      map.click(x: 60, y: 0)
      fill_in "Title", with: title
      select "Juniper", from: "Horse"
      fill_in "Minutes", with: minutes
      click_on "Log ride"
      assert_text "Ride logged."
    end
end
