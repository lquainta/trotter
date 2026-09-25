require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { username: "rider", password: "password123" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create ignores the username's case" do
    post session_path, params: { username: "RIDER", password: "password123" }

    assert_redirected_to root_path
  end

  test "create with invalid credentials" do
    post session_path, params: { username: "rider", password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create returns to the page that asked for a login" do
    get new_activity_path
    post session_path, params: { username: "rider", password: "password123" }

    assert_redirected_to new_activity_url
  end

  test "destroy" do
    sign_in_as users(:rider)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
