require "test_helper"

class Settings::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:rider)
    sign_in_as @user
  end

  test "changes the password and logs out other devices" do
    other_device = @user.sessions.create!

    patch settings_password_path, params: { user: { password_challenge: "password123", password: "newpassword1", password_confirmation: "newpassword1" } }

    assert_redirected_to settings_path
    assert @user.reload.authenticate("newpassword1")
    assert_not Session.exists?(other_device.id)
    assert Session.exists?(Current.session.id), "keeps this device logged in"
  end

  test "requires the current password" do
    patch settings_password_path, params: { user: { password_challenge: "wrong-password", password: "newpassword1", password_confirmation: "newpassword1" } }

    assert_response :unprocessable_content
    assert_select "li", text: "Current password is invalid"
    assert @user.reload.authenticate("password123")
  end

  test "a request without the current password field is rejected" do
    patch settings_password_path, params: { user: { password: "newpassword1", password_confirmation: "newpassword1" } }

    assert_response :unprocessable_content
    assert @user.reload.authenticate("password123")
  end

  test "requires a new password" do
    patch settings_password_path, params: { user: { password_challenge: "password123", password: "", password_confirmation: "" } }

    assert_response :unprocessable_content
    assert_select "li", text: "Password can't be blank"
  end
end
