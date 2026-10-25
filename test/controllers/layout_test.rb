require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  PAGES = -> { [ root_path, activities_path, user_path(users(:rider)), new_session_path, new_registration_path ] }

  test "every page has the same header and footer" do
    instance_exec(&PAGES).each do |path|
      get path

      assert_select "body > header nav a[href=?]", root_path, 2
      assert_select "body > header nav a[href=?]", activities_path
      assert_select "body > footer a[href=?]", root_path
      assert_select "body > footer a[href=?]", activities_path
      assert_select "body > footer a[href=?]", "https://github.com/lquainta/trotter"
    end
  end

  test "logged-out visitors see Log in and Sign up" do
    get root_path

    assert_select "header a[href=?]", new_session_path, text: "Log in"
    assert_select "header a[href=?]", new_registration_path, text: "Sign up"
    assert_select "header a[href=?]", settings_path, count: 0
  end

  test "logged-in riders see their profile and settings instead" do
    sign_in_as users(:rider)

    instance_exec(&PAGES).first(3).each do |path|
      get path

      assert_select "header a[href=?][title='Your profile']", user_path(users(:rider))
      assert_select "header a[href=?][title=Settings]", settings_path
      assert_select "header a[href=?]", new_session_path, count: 0
    end
  end
end
