require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create makes an account and logs in" do
    assert_difference "User.count", 1 do
      post registration_path, params: { user: { username: "New_Rider", password: "password123", password_confirmation: "password123" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert User.find_by(username: "new_rider").authenticate("password123")
  end

  test "create shows errors for a taken username and mismatched passwords" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: { username: "rider", password: "password123", password_confirmation: "different1" } }
    end

    assert_response :unprocessable_content
    assert_select "li", text: "Username has already been taken"
    assert_select "li", text: "Password confirmation doesn't match Password"
  end
end
