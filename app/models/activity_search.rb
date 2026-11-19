# The /search form. Turns the query string into chained Activity scopes, 10 rides per page.
#
#   search = ActivitySearch.new(params, unit: "mi")
#   search.filtered?  # false until at least one filter is set, so an empty search never lists every ride
#   search.results    # this page's rides
#
# Blank or unreadable values (a distance of "abc", a date of "2026-13-45") are ignored rather than
# raising an error, and they don't count as a filter.
class ActivitySearch
  PER_PAGE = 10
  SORT_LABELS = { "newest" => "Newest first", "oldest" => "Oldest first",
                  "longest" => "Longest first", "fastest" => "Fastest first" }.freeze
  METERS_PER_UNIT = ApplicationHelper::METERS_PER_UNIT

  attr_reader :keyword, :rider, :horse_id, :min_distance, :max_distance, :from, :to, :photos, :sort, :page, :unit

  def initialize(params = {}, unit: "mi", **filters)
    params = params.to_h.merge(filters).with_indifferent_access
    @unit = METERS_PER_UNIT.key?(unit) ? unit : "mi"
    @keyword = params[:q].to_s.strip.first(100).presence
    @rider = params[:rider].to_s.strip.first(20).presence
    @horse_id = positive_integer(params[:horse_id])
    @min_distance = distance(params[:min_distance])
    @max_distance = distance(params[:max_distance])
    @from = date(params[:from])
    @to = date(params[:to])
    @photos = params[:photos] == "1"
    @sort = SORT_LABELS.key?(params[:sort]) ? params[:sort] : "newest"
    @page = positive_integer(params[:page]) || 1
  end

  def filtered?
    [ keyword, rider, horse_id, min_distance, max_distance, from, to ].any? || photos
  end

  def scope
    rides = Activity.all
    rides = rides.matching(keyword) if keyword
    rides = rides.by_rider(rider) if rider
    rides = rides.on_horse(horse_id) if horse_id
    rides = rides.distance_between(meters(min_distance), meters(max_distance)) if min_distance || max_distance
    rides = rides.started_between(from, to) if from || to
    rides = rides.with_photos if photos
    rides
  end

  def total_count
    @total_count ||= filtered? ? scope.count : 0
  end

  def results
    return Activity.none unless filtered?

    @results ||= scope.with_photos_and_rider.sorted_by(sort).limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a
  end

  def total_pages
    [ (total_count / PER_PAGE.to_f).ceil, 1 ].max
  end

  def previous_page
    page - 1 if page > 1
  end

  def next_page
    page + 1 if page < total_pages
  end

  # 1-based position of the first and last result on this page, for "Showing 11–20 of 23"
  def first_position
    (page - 1) * PER_PAGE + 1
  end

  def last_position
    [ page * PER_PAGE, total_count ].min
  end

  # The filters as query parameters, for links to other pages of the same search.
  def to_params(overrides = {})
    { q: keyword, rider: rider, horse_id: horse_id, min_distance: min_distance, max_distance: max_distance,
      from: from&.iso8601, to: to&.iso8601, photos: ("1" if photos), sort: (sort unless sort == "newest") }
      .merge(overrides).compact
  end

  private
    def positive_integer(value)
      number = Integer(value.to_s, 10, exception: false)
      number if number&.positive?
    end

    def distance(value)
      number = Float(value.to_s.strip, exception: false)
      return unless number&.finite? && number >= 0

      number == number.floor ? number.to_i : number # 3, not 3.0, back in the form
    end

    def meters(distance)
      distance * METERS_PER_UNIT[unit] if distance
    end

    def date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
end
