class Activity < ApplicationRecord
  PHOTO_CONTENT_TYPES = %w[ image/jpeg image/png image/webp image/heic image/heif ].freeze
  MAX_PHOTOS = 10
  MAX_PHOTO_SIZE = 20.megabytes
  EARTH_RADIUS_METERS = 6_371_000 # Same radius Leaflet uses, so the form's live distance matches.

  belongs_to :user
  # Variants are WebP so browsers can show them even when the upload is an iPhone HEIC.
  has_many_attached :photos do |attachable|
    attachable.variant :preview, resize_to_limit: [ 1000, 1000 ], format: :webp
    attachable.variant :full, resize_to_limit: [ 2400, 2400 ], format: :webp
  end

  # route_coordinates is a native json column, so Rails already casts it to and from a
  # Ruby Array. Do NOT add `serialize :route_coordinates` - on a json column that
  # double-encodes the value and it comes back as a String.

  # duration is stored in seconds; the form edits it as separate hour/minute/second fields.
  attribute :duration_hours, :integer
  attribute :duration_minutes, :integer
  attribute :duration_seconds, :integer

  before_validation :set_duration_from_parts
  before_save :set_distance, if: :route_coordinates_changed?

  validates :title, :started_at, :duration, presence: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :duration_hours, numericality: { in: 0..99 }, allow_nil: true
  validates :duration_minutes, :duration_seconds, numericality: { in: 0..59 }, allow_nil: true
  validate :route_coordinates_are_lat_lng_pairs
  validate :photos_are_acceptable

  private
    def set_duration_from_parts
      parts = [ duration_hours, duration_minutes, duration_seconds ]
      self.duration = duration_hours.to_i * 3600 + duration_minutes.to_i * 60 + duration_seconds.to_i if parts.any?
    end

    def set_distance
      self.distance_meters = route_coordinates.each_cons(2).sum { |from, to| haversine_meters(from, to) }
    end

    # Great-circle distance, calculated the same way as Leaflet's L.CRS.Earth.distance.
    def haversine_meters((lat1, lng1), (lat2, lng2))
      radians = Math::PI / 180
      sin_dlat = Math.sin((lat2 - lat1) * radians / 2)
      sin_dlng = Math.sin((lng2 - lng1) * radians / 2)
      a = sin_dlat**2 + Math.cos(lat1 * radians) * Math.cos(lat2 * radians) * sin_dlng**2
      2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end

    def route_coordinates_are_lat_lng_pairs
      valid = route_coordinates.is_a?(Array) &&
              route_coordinates.all? { |point| point.is_a?(Array) && point.size == 2 && point.all?(Numeric) }
      errors.add(:route_coordinates, "must be a list of [lat, lng] pairs") unless valid
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
end
