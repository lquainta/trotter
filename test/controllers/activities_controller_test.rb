require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  test "the feed lists every ride, newest first, with its stats" do
    get activities_path

    assert_response :success
    assert_select "article", Activity.count
    assert_select "article:first-of-type h2", "Foothills loop"
    assert_select "##{dom_id(activities(:foothills))} dd", "6.00 mi"
    assert_select "##{dom_id(activities(:foothills))} dd", "13:20 /mi"
  end

  test "the feed links each ride to its rider and uses the viewer's units" do
    sign_in_as users(:km_rider)
    get activities_path

    assert_select "##{dom_id(activities(:foothills))} a[href=?]", user_path(users(:rider)), text: "rider"
    assert_select "##{dom_id(activities(:foothills))} dd", "9.66 km"
    assert_select "##{dom_id(activities(:foothills))} dd", "8:17 /km"
  end

  test "the feed shows a message when there are no rides" do
    Activity.delete_all
    get activities_path

    assert_select "article", 0
    assert_select "p", "No rides yet."
  end
end
