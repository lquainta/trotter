# One ride. Riders draw the route on the Log a Ride map, and the distance is calculated from it.
class Activity < ApplicationRecord
  EARTH_RADIUS_METERS = 6_371_000.0
  MAX_ROUTE_POINTS = 2_000

  belongs_to :user

  # The Log a Ride form asks for hours, minutes, and seconds; they combine into duration (in seconds).
  attribute :duration_hours, :integer
  attribute :duration_minutes, :integer
  attribute :duration_seconds, :integer

  before_validation :combine_duration_parts
  before_validation :calculate_distance, if: :route_needs_checking?

  validates :title, presence: true, length: { maximum: 100 }
  validates :started_at, presence: true
  validates :duration_hours, numericality: { in: 0..99 }, allow_nil: true
  validates :duration_minutes, :duration_seconds, numericality: { in: 0..59 }, allow_nil: true
  validates :duration, presence: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :route_is_drawn, if: :route_needs_checking?
  # A broken route already has its own error, so don't pile a distance error on top of it.
  validates :distance_meters, numericality: { greater_than: 0 }, unless: -> { errors.include?(:route_coordinates) }

  scope :newest_first, -> { order(started_at: :desc) }

  # Length in meters of a route of [latitude, longitude] points, using the haversine formula.
  # app/javascript/lib/maps.js does the same math to show the distance while the route is drawn.
  def self.route_distance(points)
    points.each_cons(2).sum do |(lat1, lng1), (lat2, lng2)|
      d_lat = (lat2 - lat1) * Math::PI / 180
      d_lng = (lng2 - lng1) * Math::PI / 180
      a = Math.sin(d_lat / 2)**2 +
        Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(d_lng / 2)**2
      2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(a))
    end
  end

  # The form sends the route as a JSON string. Text that isn't JSON, or isn't a list of
  # map points, is kept as-is so validation can reject it instead of raising an error.
  def route_coordinates=(value)
    if value.is_a?(String)
      value = begin
        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end
    end
    value = value.map { |lat, lng| [ lat.to_f.round(6), lng.to_f.round(6) ] } if route_points?(value)
    super(value)
  end

  # Meters per second
  def average_speed
    distance_meters / duration
  end

  private
    def combine_duration_parts
      parts = [ duration_hours, duration_minutes, duration_seconds ]
      self.duration = duration_hours.to_i.hours + duration_minutes.to_i.minutes + duration_seconds.to_i if parts.any?
    end

    # Rides logged before routes existed have none; leave their stored distance alone.
    def route_needs_checking?
      new_record? || route_coordinates_changed?
    end

    def calculate_distance
      self.distance_meters = route_points?(route_coordinates) ? self.class.route_distance(route_coordinates) : nil
    end

    def route_is_drawn
      if !route_points?(route_coordinates)
        errors.add(:route_coordinates, "isn't a list of map points")
      elsif route_coordinates.size < 2
        errors.add(:route_coordinates, "needs at least two points. Click the map to draw where you rode.")
      elsif route_coordinates.size > MAX_ROUTE_POINTS
        errors.add(:route_coordinates, "can have at most #{MAX_ROUTE_POINTS} points")
      end
    end

    def route_points?(value)
      value.is_a?(Array) && value.all? do |point|
        point.is_a?(Array) && point.size == 2 && point.all?(Numeric) &&
          point[0].between?(-90, 90) && point[1].between?(-180, 180)
      end
    end
end
