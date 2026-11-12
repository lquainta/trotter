# One ride. Riders draw the route on the Log a Ride map, and the distance is calculated from it.
class Activity < ApplicationRecord
  EARTH_RADIUS_METERS = 6_371_000.0
  MAX_ROUTE_POINTS = 2_000
  PHOTO_CONTENT_TYPES = %w[ image/jpeg image/png image/webp image/heic image/heif ].freeze
  MAX_PHOTOS = 10
  MAX_PHOTO_SIZE = 20.megabytes

  belongs_to :user
  belongs_to :horse, optional: true

  # Every photo is shown as a resized WebP, so iPhone HEIC photos display in any browser.
  # Deleting the ride deletes its photos too (has_many_attached purges them by default).
  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 320, 320 ], format: :webp
    attachable.variant :preview, resize_to_limit: [ 1000, 1000 ], format: :webp
    attachable.variant :full, resize_to_limit: [ 2400, 2400 ], format: :webp
  end

  # The ride form adds photos with new_photos and removes them by checking remove_photo_ids,
  # so editing a ride never drops the photos it already has.
  attribute :new_photos, default: -> { [] }
  attribute :remove_photo_ids, default: -> { [] }

  # The Log a Ride form asks for hours, minutes, and seconds; they combine into duration (in seconds).
  attribute :duration_hours, :integer
  attribute :duration_minutes, :integer
  attribute :duration_seconds, :integer
  # Remember that the form sent them, so clearing all three on Edit Ride is an error, not "no change".
  %i[ duration_hours duration_minutes duration_seconds ].each do |part|
    define_method(:"#{part}=") do |value|
      @duration_parts_given = true
      super(value)
    end
  end

  before_validation :combine_duration_parts
  before_validation :apply_photo_changes
  after_save -> { self.remove_photo_ids = [] }
  before_validation :calculate_distance, if: :route_needs_checking?

  validates :title, presence: true, length: { maximum: 100 }
  validates :started_at, presence: true
  validates :duration_hours, numericality: { in: 0..99 }, allow_nil: true
  validates :duration_minutes, :duration_seconds, numericality: { in: 0..59 }, allow_nil: true
  validates :duration, presence: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :route_is_drawn, if: :route_needs_checking?
  validate :photos_are_acceptable
  validate :horse_belongs_to_rider
  # A broken route already has its own error, so don't pile a distance error on top of it.
  validates :distance_meters, numericality: { greater_than: 0 }, unless: -> { errors.include?(:route_coordinates) }

  scope :newest_first, -> { order(started_at: :desc) }
  scope :with_photos_and_rider, -> { includes(:user, :horse, photos_attachments: :blob) }

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

  # The photos as they are in the database, ignoring changes from a form that failed to save,
  # so the Edit Ride page never tries to show a photo that was never uploaded.
  def saved_photos
    return [] if new_record?

    ActiveStorage::Attachment.where(record: self, name: "photos").includes(:blob).order(:id)
  end

  def removing_photo?(attachment)
    remove_photo_ids.map(&:to_s).include?(attachment.id.to_s)
  end

  private
    def combine_duration_parts
      return unless @duration_parts_given

      parts = [ duration_hours, duration_minutes, duration_seconds ]
      self.duration = parts.any? ? duration_hours.to_i.hours + duration_minutes.to_i.minutes + duration_seconds.to_i : nil
    end

    def apply_photo_changes
      uploads = Array(new_photos).compact_blank
      removals = Array(remove_photo_ids).compact_blank.map(&:to_i)
      return if uploads.empty? && removals.empty?

      kept = photos.attachments.reject { |attachment| attachment.persisted? && removals.include?(attachment.id) }
      self.photos = kept.map(&:blob) + uploads
      # Uploads are attached now; forget them so validating or saving again doesn't attach them twice.
      self.new_photos = []
    end

    # A form can't tie a ride to someone else's horse by sending its id.
    def horse_belongs_to_rider
      errors.add(:horse, "must be one of your horses") if horse && horse.user_id != user_id
    end

    def photos_are_acceptable
      errors.add(:photos, "can't be more than #{MAX_PHOTOS}") if photos.size > MAX_PHOTOS
      if photos.any? { |photo| !photo.content_type.in?(PHOTO_CONTENT_TYPES) }
        errors.add(:photos, "must be JPEG, PNG, WebP, or HEIC images")
      end
      if photos.any? { |photo| photo.byte_size > MAX_PHOTO_SIZE }
        errors.add(:photos, "must each be smaller than #{MAX_PHOTO_SIZE / 1.megabyte} MB")
      end
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
