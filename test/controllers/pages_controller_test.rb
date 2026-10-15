require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the landing page links to every section and shows recent rides" do
    get root_path

    assert_response :success
    assert_select "header a[href=?]", root_path
    assert_select "header a[href=?]", activities_path
    assert_select "main a[href=?]", new_registration_path
    assert_select "main a[href=?]", new_session_path
    assert_select "main a[href=?]", new_activity_path
    assert_select "main a[href=?]", settings_path
    assert_select "main article", count: [ Activity.count, 3 ].min
  end

  test "every page has the shared header and footer" do
    sign_in_as users(:rider)

    [ root_path, activities_path, new_activity_path, settings_path, user_path(users(:rider)) ].each do |path|
      get path
      assert_response :success
      assert_select "body > header nav", 1
      assert_select "body > footer a[href=?]", activities_path
      assert_select "body > footer a[href=?]", "https://www.openstreetmap.org/copyright"
    end
  end

  test "the pre-launch home page is just Hello World, with no links" do
    with_routing do |routes|
      routes.draw { root "pages#hello" }

      get root_path

      assert_response :success
      assert_select "h1", "Hello World"
      assert_select "a", count: 0
      assert_select "nav", count: 0
    end
  end
end
