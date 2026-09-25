class ActivitiesController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @activities = Activity.includes(:user).with_attached_photos.order(started_at: :desc)
  end

  def new
    @activity = Current.user.activities.build(started_at: Time.current.beginning_of_minute)
  end

  def create
    @activity = Current.user.activities.build(activity_params)

    if @activity.save
      redirect_to activities_path, notice: "Ride saved!"
    else
      # Turbo only renders a failed form submission when it gets a 4xx status.
      render :new, status: :unprocessable_content
    end
  end

  private
    def activity_params
      permitted = params.expect(activity: [ :title, :description, :started_at, :duration_hours, :duration_minutes,
                                            :duration_seconds, :route_coordinates, photos: [] ])
      permitted.merge(route_coordinates: parse_route_coordinates(permitted[:route_coordinates]))
    end

    # The hidden field posts the route as a JSON string, e.g. "[[43.606,-116.204],[43.61,-116.21]]".
    # Parse it into an Array of [lat, lng] Floats, dropping anything malformed or out of range.
    def parse_route_coordinates(json)
      return [] if json.blank?

      points = JSON.parse(json)
      return [] unless points.is_a?(Array)

      points.filter_map do |point|
        next unless point.is_a?(Array) && point.size == 2

        lat, lng = point.map { |value| Float(value, exception: false) }
        [ lat.round(6), lng.round(6) ] if lat&.between?(-90, 90) && lng&.between?(-180, 180)
      end
    rescue JSON::ParserError
      []
    end
end
