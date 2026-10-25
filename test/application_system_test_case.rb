require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Chrome's "this password was in a data breach" warning (test passwords like password123 trigger it)
    # takes over the mouse, so clicks never reach the page.
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
  end

  private
    def log_in_as(user, password: "password123")
      visit new_session_url
      fill_in "Username", with: user.username
      fill_in "Password", with: password
      click_button "Log in"
      assert_selector "a[title='Your profile']"
    end
end
