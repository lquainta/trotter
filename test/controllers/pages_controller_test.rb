require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the landing page links to every section and shows the three newest rides" do
    get root_path

    assert_response :success
    assert_select "h1", "Every ride, logged and shared"
    assert_select "main a[href=?]", activities_path
    assert_select "main article", 3
    assert_select "main article h2", text: "Creek crossing practice", count: 0
  end
end
