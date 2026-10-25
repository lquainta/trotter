module ApplicationHelper
  AVATAR_COLORS = %w[ bg-amber-600 bg-emerald-600 bg-sky-600 bg-rose-600 bg-violet-600 bg-teal-600 ].freeze
  METERS_PER_UNIT = { "mi" => 1609.344, "km" => 1000.0 }.freeze

  # "system" follows the device's light/dark setting (see the dark variant in app/assets/tailwind/application.css).
  def current_theme
    Current.user&.theme || "system"
  end

  # The viewer's preference from Settings; logged-out visitors see miles.
  def current_distance_unit
    Current.user&.distance_unit || "mi"
  end

  # A colored circle with the user's first letter. A given username always gets the same color.
  def avatar_for(user, size: "size-10 text-base")
    tag.span user.username.first.upcase, aria: { hidden: true }, class: [
      "inline-flex shrink-0 items-center justify-center rounded-full font-semibold text-white",
      size, AVATAR_COLORS[user.username.sum % AVATAR_COLORS.size]
    ]
  end

  # 9656 => "6.00 mi", or "9.66 km"
  def format_distance(meters, unit = current_distance_unit)
    "#{number_with_precision(meters / METERS_PER_UNIT[unit], precision: 2)} #{unit}"
  end

  # 4800 => "1h 20m", 2700 => "45m", 615 => "10m 15s"
  def format_duration(seconds)
    hours, remainder = seconds.to_i.divmod(3600)
    minutes, seconds = remainder.divmod(60)
    if hours.positive? then "#{hours}h #{minutes}m"
    elsif seconds.positive? then "#{minutes}m #{seconds}s"
    else "#{minutes}m"
    end
  end

  # Time per mile or km: 9656 meters in 4800 seconds => "13:20 /mi"
  def format_pace(meters, seconds, unit = current_distance_unit)
    return "—" unless meters.to_f.positive?

    minutes, seconds = (seconds / (meters / METERS_PER_UNIT[unit])).round.divmod(60)
    format("%d:%02d /%s", minutes, seconds, unit)
  end
end
