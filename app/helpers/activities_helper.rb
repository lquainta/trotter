module ActivitiesHelper
  METERS_PER_UNIT = { "mi" => 1609.344, "km" => 1000.0 }.freeze
  SPEED_UNITS = { "mi" => "mph", "km" => "km/h" }.freeze

  # The viewer's preference from Settings; logged-out visitors see miles.
  def current_distance_unit
    Current.user&.distance_unit || "mi"
  end

  # 2011.68 => "1.25 mi"
  def format_distance(meters, unit = current_distance_unit)
    return "—" unless meters.to_f.positive?

    "#{number_with_precision(meters / METERS_PER_UNIT[unit], precision: 2)} #{unit}"
  end

  # 4980 => "1h 23m", 754 => "12m 34s"
  def format_duration(seconds)
    return "—" unless seconds.to_i.positive?

    hours, remainder = seconds.to_i.divmod(3600)
    minutes, seconds = remainder.divmod(60)
    if hours.positive?
      "#{hours}h #{minutes}m"
    elsif minutes.positive?
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  # Time per mile or km: "7:30 /mi"
  def format_pace(meters, seconds, unit = current_distance_unit)
    return "—" unless meters.to_f.positive? && seconds.to_i.positive?

    minutes, seconds = (seconds / (meters / METERS_PER_UNIT[unit])).round.divmod(60)
    format("%d:%02d /%s", minutes, seconds, unit)
  end

  # "8.0 mph"
  def format_speed(meters, seconds, unit = current_distance_unit)
    return "—" unless meters.to_f.positive? && seconds.to_i.positive?

    per_hour = (meters / METERS_PER_UNIT[unit]) / (seconds / 3600.0)
    "#{number_with_precision(per_hour, precision: 1)} #{SPEED_UNITS[unit]}"
  end

  # "Today at 7:15 AM", "Yesterday at 6:02 PM", "September 3, 2026 at 9:00 AM"
  def format_start_time(time)
    day = if time.to_date == Date.current then "Today"
    elsif time.to_date == Date.yesterday then "Yesterday"
    else time.strftime("%B %-d, %Y")
    end
    "#{day} at #{time.strftime("%-l:%M %p")}"
  end
end
