require "test_helper"

class ActivitySearchTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Fixture rides: foothills (rider, on Biscuit, 6 mi, 1 day ago), arena (km_rider, 1 mi, 3 days ago),
  # hack (km_rider, 3 mi, 5 days ago), and creek (rider, 4 mi, 7 days ago).

  test "no filters means no results, not every ride" do
    search = ActivitySearch.new({})

    assert_not search.filtered?
    assert_empty search.results
    assert_equal 0, search.total_count
  end

  test "sort and page alone aren't filters" do
    assert_not ActivitySearch.new(sort: "longest", page: "2").filtered?
  end

  test "blank and unreadable values are ignored" do
    search = ActivitySearch.new(q: "  ", rider: "", horse_id: "abc", min_distance: "far", max_distance: "-1",
                                from: "2026-13-45", to: "yesterday", photos: "0", sort: "random", page: "-3")

    assert_not search.filtered?
    assert_equal "newest", search.sort
    assert_equal 1, search.page
  end

  test "keyword filter matches the title or description, ignoring case" do
    assert_rides %i[ foothills ], q: "GULCH" # in its description
    assert_rides %i[ creek ], q: "creek" # in its title
    assert_rides %i[ foothills arena ], q: "oo" # "Foothills loop", "Arena schooling"
    assert_rides %i[ hack ], q: "morning hack"
  end

  test "keyword filter treats % and _ as plain characters" do
    assert_rides [], q: "%"
    assert_rides [], q: "_"
  end

  test "rider filter matches a username, ignoring case and spaces" do
    assert_rides %i[ foothills creek ], rider: " Rider "
    assert_rides %i[ arena hack ], rider: "km_rider"
    assert_rides [], rider: "nobody"
  end

  test "horse filter matches rides on that horse" do
    assert_rides %i[ foothills ], horse_id: horses(:biscuit).id.to_s
    assert_rides [], horse_id: horses(:pepper).id.to_s
  end

  test "distance filter uses the viewer's units" do
    assert_rides %i[ foothills creek hack ], min_distance: "2.9"
    assert_rides %i[ arena hack ], max_distance: "3.1"
    assert_rides %i[ creek hack ], min_distance: "2.5", max_distance: "4.5"
    # 5 km is about 3.1 miles: only arena (1.6 km) and hack (4.8 km) are under it
    assert_rides %i[ arena hack ], { max_distance: "5" }, unit: "km"
  end

  test "date filter includes both whole days" do
    travel_to Time.current do
      assert_rides %i[ foothills arena ], from: 3.days.ago.to_date.iso8601
      assert_rides %i[ hack creek ], to: 5.days.ago.to_date.iso8601
      assert_rides %i[ arena hack ], from: 5.days.ago.to_date.iso8601, to: 3.days.ago.to_date.iso8601
    end
  end

  test "photos filter keeps only rides with at least one photo" do
    assert_rides [], photos: "1"

    activities(:hack).photos.attach(io: file_fixture("trail.jpg").open, filename: "trail.jpg", content_type: "image/jpeg")
    assert_rides %i[ hack ], photos: "1"
    assert_rides %i[ hack ], photos: "1", rider: "km_rider"
    assert_rides [], photos: "1", rider: "rider"
  end

  test "filters combine" do
    assert_rides %i[ creek ], rider: "rider", max_distance: "5"
    assert_rides %i[ foothills ], rider: "rider", q: "loop", min_distance: "1"
  end

  test "sorting by newest, oldest, longest, and fastest" do
    any = { min_distance: "0" }
    assert_equal ordered(%i[ foothills arena hack creek ]), ActivitySearch.new(any).results
    assert_equal ordered(%i[ creek hack arena foothills ]), ActivitySearch.new(any.merge(sort: "oldest")).results
    assert_equal ordered(%i[ foothills creek hack arena ]), ActivitySearch.new(any.merge(sort: "longest")).results
    # Speeds in m/s: arena 2.6, foothills 2.0, hack 1.8, creek 1.65
    assert_equal ordered(%i[ arena foothills hack creek ]), ActivitySearch.new(any.merge(sort: "fastest")).results
  end

  test "results come 10 per page" do
    12.times do |index|
      users(:newcomer).activities.create!(title: "Lap #{index}", started_at: index.hours.ago, duration: 600,
                                          route_coordinates: [ [ 43.6, -116.2 ], [ 43.61, -116.2 ] ])
    end

    first = ActivitySearch.new(rider: "newcomer")
    assert_equal 12, first.total_count
    assert_equal 10, first.results.size
    assert_equal "Lap 0", first.results.first.title
    assert_equal [ 1, 10, 2 ], [ first.first_position, first.last_position, first.next_page ]
    assert_nil first.previous_page

    second = ActivitySearch.new(rider: "newcomer", page: "2")
    assert_equal [ "Lap 10", "Lap 11" ], second.results.map(&:title)
    assert_equal [ 11, 12, 1 ], [ second.first_position, second.last_position, second.previous_page ]
    assert_nil second.next_page
  end

  test "page links keep the filters" do
    search = ActivitySearch.new(q: "loop", min_distance: "1", photos: "1", sort: "longest", from: "2026-11-01")

    assert_equal({ q: "loop", min_distance: 1, from: "2026-11-01", photos: "1", sort: "longest", page: 2 },
                 search.to_params(page: 2))
  end

  private
    def assert_rides(names, params = {}, unit: "mi", **filters)
      params = params.merge(filters)
      search = ActivitySearch.new(params, unit: unit)
      assert search.filtered?, "expected #{params} to count as a filter"
      assert_equal names.map { |name| activities(name).id }.sort, search.results.map(&:id).sort, "searching #{params}"
    end

    def ordered(names)
      names.map { |name| activities(name) }
    end
end
