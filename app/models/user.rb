class User < ApplicationRecord
  THEMES = %w[ system light dark ].freeze
  DISTANCE_UNITS = %w[ mi km ].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :activities, dependent: :destroy

  normalizes :username, with: ->(username) { username.strip.downcase }

  validates :username, presence: true, uniqueness: true
  validates :username, length: { in: 3..20 }, allow_blank: true,
    format: { with: /\A[a-z0-9_]+\z/, message: "can only contain letters, numbers, and underscores" }
  validates :password, length: { minimum: 8 }, allow_nil: true
  # has_secure_password ignores a blank password, so changing it needs an explicit check.
  validates :password, presence: true, on: :password_change
  validates :theme, inclusion: { in: THEMES }
  validates :distance_unit, inclusion: { in: DISTANCE_UNITS }

  # Profile URLs use the username: /users/landon
  def to_param
    username
  end
end
