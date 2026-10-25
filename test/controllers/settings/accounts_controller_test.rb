require "test_helper"

class Settings::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:rider)
    sign_in_as @user
  end

  test "deletes the account, its rides, and its sessions, and logs out" do
    assert_difference -> { User.count } => -1, -> { Activity.count } => -2 do
      delete settings_account_path, params: { user: { password_challenge: "password123" } }
    end

    assert_redirected_to root_path
    assert_not User.exists?(@user.id)
    assert_not Session.exists?(user_id: @user.id)
    assert_empty cookies[:session_id]
  end

  test "requires the password" do
    assert_no_difference -> { User.count } do
      delete settings_account_path, params: { user: { password_challenge: "wrong-password" } }
    end

    assert_redirected_to settings_path
    assert_equal "That password isn't right, so your account wasn't deleted.", flash[:alert]
  end

  test "requires an account" do
    sign_out

    assert_no_difference -> { User.count } do
      delete settings_account_path, params: { user: { password_challenge: "password123" } }
    end
    assert_redirected_to new_session_url
  end
end
