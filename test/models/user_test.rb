require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "usernames are stored lowercase without surrounding spaces" do
    user = User.create!(username: "  Trail_Boss ", password: "password123")

    assert_equal "trail_boss", user.username
    assert_equal user, User.find_by(username: "TRAIL_BOSS")
  end

  test "usernames must be unique regardless of case" do
    user = User.new(username: "RIDER", password: "password123")

    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "usernames must be 3-20 letters, numbers, or underscores" do
    %w[ ab has-dash has.dot twenty_one_characters ].each do |username|
      assert_not User.new(username: username, password: "password123").valid?, "#{username} should be invalid"
    end
    assert User.new(username: "abc", password: "password123").valid?
  end

  test "passwords must be at least 8 characters" do
    user = User.new(username: "shorty", password: "short")

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "defaults to the system theme and miles" do
    user = User.new

    assert_equal "system", user.theme
    assert_equal "mi", user.distance_unit
  end

  test "rejects unknown themes and units" do
    user = users(:rider)

    assert_not user.update(theme: "neon")
    assert_not user.update(theme: "dark", distance_unit: "furlongs")
  end

  test "profile URLs use the username" do
    assert_equal "rider", users(:rider).to_param
  end
end
