require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "settings require an account" do
    get settings_path

    assert_redirected_to new_session_url
  end

  test "show checks the current preferences" do
    sign_in_as users(:km_rider)
    get settings_path

    assert_response :success
    assert_select "input[name='user[theme]'][value=dark][checked]"
    assert_select "input[name='user[distance_unit]'][value=km][checked]"
  end

  test "update saves the theme and units, and the page uses the new theme" do
    sign_in_as users(:rider)

    patch settings_path, params: { user: { theme: "dark", distance_unit: "km" } }

    assert_redirected_to settings_path
    assert_equal [ "dark", "km" ], users(:rider).reload.values_at(:theme, :distance_unit)
    follow_redirect!
    assert_select "body[data-theme=dark]"
  end

  test "update rejects unknown values" do
    sign_in_as users(:rider)

    patch settings_path, params: { user: { theme: "neon" } }

    assert_redirected_to settings_path
    assert_equal "Theme is not included in the list", flash[:alert]
    assert_equal "system", users(:rider).reload.theme
  end

  test "logged-out pages follow the device theme" do
    get activities_path

    assert_select "body[data-theme=system]"
  end
end
