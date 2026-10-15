module ApplicationHelper
  # 9656 => "6.00 mi"
  def format_miles(activity)
    "#{number_with_precision(activity.miles, precision: 2)} mi"
  end

  # 4800 => "1h 20m", 2700 => "45m", 615 => "10m 15s"
  def format_duration(seconds)
    hours, remainder = seconds.divmod(3600)
    minutes, seconds = remainder.divmod(60)
    if hours.positive? then "#{hours}h #{minutes}m"
    elsif seconds.positive? then "#{minutes}m #{seconds}s"
    else "#{minutes}m"
    end
  end

  # Seconds per mile => "13:20 /mi"
  def format_pace(activity)
    minutes, seconds = activity.pace.round.divmod(60)
    format("%d:%02d /mi", minutes, seconds)
  end
end
