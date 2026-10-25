require "application_system_test_case"

class AccountsTest < ApplicationSystemTestCase
  test "signing up, then viewing your profile" do
    visit root_url
    within("header") { click_on "Sign up" }

    fill_in "Username", with: "Trail_Rider"
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "password123"
    click_on "Create account"

    assert_text "Welcome to Trotter, trail_rider!"
    find("a[title='Your profile']").click
    assert_selector "h1", text: "trail_rider"
    assert_text "You haven't logged any rides yet."
  end

  test "logging in and out" do
    log_in_as users(:rider)

    find("a[title=Settings]").click
    click_on "Log out"

    assert_text "You've been logged out."
    within("header") { assert_link "Log in" }
  end

  test "switching between light, dark, and system themes" do
    log_in_as users(:rider)
    find("a[title=Settings]").click

    choose_option "Dark"
    click_on "Save preferences"
    assert_text "Settings saved."
    assert_selector "body[data-theme=dark]"
    assert page_is_dark?
    assert_equal "dark", page.evaluate_script("document.querySelector('meta[name=color-scheme]').content")

    choose_option "Light"
    click_on "Save preferences"
    assert_selector "body[data-theme=light]"
    assert_not page_is_dark?

    choose_option "System"
    click_on "Save preferences"
    assert_selector "body[data-theme=system]"
    emulate_color_scheme "dark"
    assert page_is_dark?, "System should follow a dark device"
    emulate_color_scheme "light"
    assert_not page_is_dark?, "System should follow a light device"
  end

  test "logging in applies your theme right away, and logging out goes back to the device theme" do
    emulate_color_scheme "light"
    log_in_as users(:km_rider) # prefers dark

    assert_selector "body[data-theme=dark]"
    assert page_is_dark?

    find("a[title=Settings]").click
    click_on "Log out"
    assert_text "You've been logged out."
    assert_selector "body[data-theme=system]"
    assert_not page_is_dark?
  end

  test "switching distance units" do
    log_in_as users(:rider)
    find("a[title=Settings]").click

    choose_option "Kilometers"
    click_on "Save preferences"
    within("header") { click_on "Feed" }

    within("##{dom_id(activities(:foothills))}") { assert_text "9.66 km" }
  end

  test "changing your password" do
    log_in_as users(:rider)
    find("a[title=Settings]").click

    fill_in "Current password", with: "password123"
    fill_in "New password", with: "newpassword1"
    fill_in "Confirm new password", with: "newpassword1"
    click_on "Change password"
    assert_text "Password changed."

    click_on "Log out"
    log_in_as users(:rider), password: "newpassword1"
  end

  test "deleting your account" do
    ride_title = activities(:foothills).title
    log_in_as users(:rider)
    find("a[title=Settings]").click

    fill_in "delete_account_password", with: "password123"
    accept_confirm { click_on "Delete my account" }

    assert_text "Your account and rides have been deleted."
    within("header") { assert_link "Sign up" }
    assert_no_text ride_title
  end

  private
    # The radio buttons are visually hidden inside styled labels, so click the label.
    def choose_option(label)
      find("label", text: label, exact_text: true).click
    end

    def emulate_color_scheme(scheme)
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: scheme } ])
    end

    def page_is_dark?
      color = page.evaluate_script("getComputedStyle(document.body).backgroundColor")
      if (lightness = color[/oklch\(([\d.]+)/, 1])
        lightness.to_f < 0.5
      else
        color.scan(/[\d.]+/).first(3).sum(&:to_f) / 3 < 128
      end
    end
end
