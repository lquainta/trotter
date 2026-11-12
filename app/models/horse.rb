# A rider's horse. Rides can be tied to one, and its profile adds up how much work it has done.
class Horse < ApplicationRecord
  PHOTO_CONTENT_TYPES = Activity::PHOTO_CONTENT_TYPES
  MAX_PHOTO_SIZE = Activity::MAX_PHOTO_SIZE
  FIRST_BIRTH_YEAR = 1970

  belongs_to :user
  # Deleting a horse keeps its rides; they just no longer list a horse (the foreign key also nullifies).
  has_many :activities, dependent: :nullify

  # Shown as a resized WebP, so an iPhone HEIC photo displays in any browser.
  has_one_attached :photo do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 320, 320 ], format: :webp
    attachable.variant :profile, resize_to_fill: [ 800, 800 ], format: :webp
  end

  # The Edit Horse form's "Remove photo" checkbox
  attribute :remove_photo, :boolean, default: false

  normalizes :name, :breed, :color, with: ->(value) { value.strip.presence }

  # Uploading a new photo replaces the old one, so "Remove photo" only matters when no new photo was chosen.
  before_validation -> { self.photo = nil if remove_photo && !attachment_changes.key?("photo") }
  after_save -> { self.remove_photo = false }

  validates :name, presence: true, length: { maximum: 50 }
  validates :breed, :color, length: { maximum: 50 }
  validates :notes, length: { maximum: 1000 }
  validates :birth_year, numericality: { only_integer: true, greater_than_or_equal_to: FIRST_BIRTH_YEAR,
                                         less_than_or_equal_to: ->(_horse) { Date.current.year } }, allow_nil: true
  validate :photo_is_acceptable

  scope :by_name, -> { order(Arel.sql("LOWER(name)")) }

  def age
    Date.current.year - birth_year if birth_year
  end

  # Rides, distance (meters), and time (seconds) for rides that started in range (all rides when nil).
  def workload(range = nil)
    rides = range ? activities.where(started_at: range) : activities
    totals = rides.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(distance_meters), 0)"), Arel.sql("COALESCE(SUM(duration), 0)"))
    { rides: totals[0], distance: totals[1].to_f, duration: totals[2].to_i }
  end

  # Distance (meters) for each of the last `weeks` weeks, oldest first: [[week start date, meters], ...]
  def weekly_distances(weeks: 8)
    first_week = weeks.pred.weeks.ago.beginning_of_week
    totals = activities.where(started_at: first_week..).pluck(:started_at, :distance_meters)
      .group_by { |started_at, _| started_at.beginning_of_week.to_date }
      .transform_values { |rides| rides.sum { |_, meters| meters } }
    Array.new(weeks) do |index|
      week = (first_week + index.weeks).to_date
      [ week, totals.fetch(week, 0.0) ]
    end
  end

  private
    def photo_is_acceptable
      return unless photo.attached?

      errors.add(:photo, "must be a JPEG, PNG, WebP, or HEIC image") unless photo.content_type.in?(PHOTO_CONTENT_TYPES)
      errors.add(:photo, "must be smaller than #{MAX_PHOTO_SIZE / 1.megabyte} MB") if photo.byte_size > MAX_PHOTO_SIZE
    end
end
