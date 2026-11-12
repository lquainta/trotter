require "test_helper"

class HorsesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "anyone can see a horse's profile with its details, workload, and rides" do
    get horse_path(horses(:biscuit))

    assert_response :success
    assert_select "h1", "Biscuit"
    assert_select "p", /Quarter Horse · Bay · \d+ years old/
    assert_select "a[href=?]", user_path(users(:rider)), text: "rider"
    assert_select "p", "Loves the hills."
    assert_select "#workload-all-time dd", "1"
    assert_select "#workload-all-time dd", "6.00 mi"
    assert_select "#workload-all-time dd", "1h 20m"
    assert_select "#workload-this-week"
    assert_select "#workload-this-month"
    assert_select "ol[aria-label^='Distance per week'] li", 8
    assert_select "article##{dom_id(activities(:foothills))}"
    assert_select "article", 1
  end

  test "only the owner sees Edit and Delete on a horse's profile" do
    get horse_path(horses(:biscuit))
    assert_select "a[href=?]", edit_horse_path(horses(:biscuit)), count: 0

    sign_in_as users(:km_rider)
    get horse_path(horses(:biscuit))
    assert_select "a[href=?]", edit_horse_path(horses(:biscuit)), count: 0
    assert_select "form[action=?]", horse_path(horses(:biscuit)), count: 0

    sign_in_as users(:rider)
    get horse_path(horses(:biscuit))
    assert_select "a[href=?]", edit_horse_path(horses(:biscuit)), text: "Edit"
    assert_select "form[action=?] input[name=_method][value=delete]", horse_path(horses(:biscuit))
  end

  test "a horse that doesn't exist is not found" do
    get horse_path(id: 0)
    assert_response :not_found
  end

  test "adding a horse requires an account" do
    get new_horse_path
    assert_redirected_to new_session_path

    assert_no_difference("Horse.count") { post horses_path, params: { horse: { name: "Sneaky" } } }
    assert_redirected_to new_session_path
  end

  test "adding a horse with a photo saves it to your account" do
    sign_in_as users(:newcomer)
    get new_horse_path
    assert_select "input[name=?]", "horse[name]"
    assert_select "input[type=file][name=?]", "horse[photo]"

    assert_difference "users(:newcomer).horses.count" do
      post horses_path, params: { horse: { name: "Juniper", breed: "Arabian", color: "Grey", birth_year: "2018",
                                           notes: "Forward.", photo: photo("trail.jpg"), user_id: users(:rider).id } }
    end
    horse = users(:newcomer).horses.last
    assert_redirected_to horse_path(horse)
    assert_equal "Juniper added.", flash[:notice]
    assert_equal [ "Arabian", "Grey", 2018 ], [ horse.breed, horse.color, horse.birth_year ]
    assert horse.photo.attached?
  end

  test "a horse with errors shows them" do
    sign_in_as users(:newcomer)

    assert_no_difference("Horse.count") { post horses_path, params: { horse: { name: "", birth_year: "1800" } } }
    assert_response :unprocessable_content
    assert_select "li", "Name can't be blank"
    assert_select "li", /Birth year must be greater than or equal to/
  end

  test "editing a horse updates it and can remove its photo" do
    horse = horses(:biscuit)
    horse.update!(photo: photo("trail.jpg"))
    sign_in_as users(:rider)

    get edit_horse_path(horse)
    assert_select "input[name=?][value=?]", "horse[name]", "Biscuit"
    assert_select "input[type=checkbox][name=?]", "horse[remove_photo]"
    assert_select "form[action=?] button", horse_path(horse), text: "Delete horse"

    perform_enqueued_jobs do
      patch horse_path(horse), params: { horse: { name: "Biscuit II", remove_photo: "1" } }
    end
    assert_redirected_to horse_path(horse)
    assert_equal "Biscuit II", horse.reload.name
    assert_not horse.photo.attached?
  end

  test "deleting a horse keeps its rides" do
    sign_in_as users(:rider)

    assert_difference("Horse.count", -1) do
      assert_no_difference("Activity.count") { delete horse_path(horses(:biscuit)) }
    end
    assert_redirected_to user_path(users(:rider))
    assert_nil activities(:foothills).reload.horse_id
  end

  test "another rider can't edit, update, or delete your horse" do
    horse = horses(:biscuit)
    sign_in_as users(:km_rider)

    get edit_horse_path(horse)
    assert_response :not_found
    patch horse_path(horse), params: { horse: { name: "Stolen" } }
    assert_response :not_found
    assert_no_difference("Horse.count") { delete horse_path(horse) }
    assert_response :not_found
    assert_equal "Biscuit", horse.reload.name
  end

  test "rider profiles list their horses, and your own has an Add a horse card" do
    get user_path(users(:rider))
    assert_select "a[href=?]", horse_path(horses(:biscuit)), text: /Biscuit/
    assert_select "a[href=?]", new_horse_path, count: 0

    sign_in_as users(:rider)
    get user_path(users(:rider))
    assert_select "a[href=?]", new_horse_path, text: /Add a horse/
  end

  private
    def photo(name, type = nil)
      Rack::Test::UploadedFile.new(file_fixture(name), type)
    end
end
