require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "every page has the same header and footer" do
    [ root_path, activities_path ].each do |path|
      get path

      assert_select "body > header nav a[href=?]", root_path, 2
      assert_select "body > header nav a[href=?]", activities_path
      assert_select "body > footer a[href=?]", root_path
      assert_select "body > footer a[href=?]", activities_path
      assert_select "body > footer a[href=?]", "https://github.com/lquainta/trotter"
    end
  end
end
