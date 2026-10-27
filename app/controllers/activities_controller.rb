class ActivitiesController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @activities = Activity.includes(:user).newest_first
  end

  def new
    @activity = Current.user.activities.new(started_at: Time.current.beginning_of_minute)
  end

  def create
    @activity = Current.user.activities.new(activity_params)

    if @activity.save
      redirect_to activities_path, notice: "Ride logged."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # route_coordinates arrives as a JSON string from the map; Activity#route_coordinates= parses it.
    def activity_params
      params.expect(activity: [ :title, :description, :started_at, :duration_hours, :duration_minutes, :duration_seconds,
                                :route_coordinates ])
    end
end
