require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
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
