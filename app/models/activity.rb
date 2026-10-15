# One ride. Until riders can log their own (Checkpoint 3), rides come from db/seeds.rb.
class Activity < ApplicationRecord
  METERS_PER_MILE = 1609.344

  validates :rider_name, :title, :started_at, presence: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }
  validates :distance_meters, numericality: { greater_than: 0 }

  scope :newest_first, -> { order(started_at: :desc) }

  def miles
    distance_meters / METERS_PER_MILE
  end

  # Seconds per mile.
  def pace
    duration / miles
  end
end
