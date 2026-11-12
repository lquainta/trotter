require "test_helper"

class HorseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "a horse needs a name" do
    horse = users(:rider).horses.new(name: "  ")

    assert_not horse.valid?
    assert_equal [ "Name can't be blank" ], horse.errors.full_messages
  end

  test "birth year must be a real past year" do
    horse = users(:rider).horses.new(name: "Colt")

    horse.birth_year = Date.current.year + 1
    assert_not horse.valid?
    horse.birth_year = 1900
    assert_not horse.valid?
    horse.birth_year = Date.current.year
    assert horse.valid?
    assert_equal 0, horse.age
  end

  test "age comes from the birth year" do
    travel_to Date.new(2026, 11, 12) do
      assert_equal 12, horses(:biscuit).age
    end
    assert_nil horses(:pepper).age
  end

  test "workload adds up rides, distance, and time in a period" do
    travel_to Time.zone.local(2026, 11, 12, 12) do # a Thursday
      horse = horses(:pepper)
      ride_on horse, Time.zone.local(2026, 11, 10, 9), meters: 1000, seconds: 600   # this week
      ride_on horse, Time.zone.local(2026, 11, 3, 9), meters: 2000, seconds: 1200   # earlier this month
      ride_on horse, Time.zone.local(2026, 10, 20, 9), meters: 4000, seconds: 2400  # last month

      assert_equal({ rides: 1, distance: 1000.0, duration: 600 }, horse.workload(Time.current.all_week))
      assert_equal({ rides: 2, distance: 3000.0, duration: 1800 }, horse.workload(Time.current.all_month))
      assert_equal({ rides: 3, distance: 7000.0, duration: 4200 }, horse.workload)
    end
  end

  test "a horse with no rides has an empty workload" do
    assert_equal({ rides: 0, distance: 0.0, duration: 0 }, horses(:pepper).workload)
  end

  test "weekly distances cover the last eight weeks, oldest first, with empty weeks as zero" do
    travel_to Time.zone.local(2026, 11, 12, 12) do
      horse = horses(:pepper)
      ride_on horse, Time.zone.local(2026, 11, 10, 9), meters: 1000
      ride_on horse, Time.zone.local(2026, 11, 9, 9), meters: 500
      ride_on horse, Time.zone.local(2026, 10, 27, 9), meters: 2000
      ride_on horse, Time.zone.local(2026, 9, 1, 9), meters: 9999 # too long ago

      weeks = horse.weekly_distances
      assert_equal 8, weeks.size
      assert_equal Date.new(2026, 9, 21), weeks.first.first
      assert_equal [ Date.new(2026, 11, 9), 1500.0 ], weeks.last
      assert_equal [ Date.new(2026, 10, 26), 2000.0 ], weeks[-3]
      assert_equal 3500.0, weeks.sum(&:last)
    end
  end

  test "deleting a horse keeps its rides, without a horse" do
    ride = activities(:foothills)

    assert_no_difference "Activity.count" do
      horses(:biscuit).destroy!
    end
    assert_nil ride.reload.horse_id
  end

  test "a ride can't be tied to another rider's horse" do
    ride = activities(:foothills)
    ride.horse = horses(:pepper)

    assert_not ride.valid?
    assert_includes ride.errors.full_messages, "Horse must be one of your horses"
  end

  test "deleting a rider deletes their horses" do
    assert_difference "Horse.count", -1 do
      users(:km_rider).destroy!
    end
  end

  test "a horse can have a photo, and Remove photo takes it off" do
    horse = horses(:pepper)
    horse.update!(photo: photo("iphone.heic"))
    assert horse.reload.photo.attached?
    assert_equal "image/webp", horse.photo.variant(:thumb).processed.image.blob.content_type

    perform_enqueued_jobs { horse.update!(remove_photo: true) }
    assert_not horse.reload.photo.attached?
  end

  test "choosing a new photo wins over Remove photo" do
    horse = horses(:pepper)
    horse.update!(photo: photo("trail.jpg"))

    horse.update!(photo: photo("pasture.png"), remove_photo: true)
    assert_equal "pasture.png", horse.reload.photo.filename.to_s
  end

  test "a horse's photo must be an image" do
    horse = horses(:pepper)
    horse.photo = photo("notes.txt", "text/plain")

    assert_not horse.valid?
    assert_equal [ "Photo must be a JPEG, PNG, WebP, or HEIC image" ], horse.errors.full_messages
  end

  private
    def ride_on(horse, started_at, meters:, seconds: 600)
      ride = horse.user.activities.create!(horse: horse, title: "Ride", started_at: started_at, duration: seconds,
        route_coordinates: [ [ 0, 0 ], [ 0.01, 0 ] ])
      ride.update_column(:distance_meters, meters)
    end

    def photo(name, type = nil)
      Rack::Test::UploadedFile.new(file_fixture(name), type)
    end
end
