class ActivitiesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  # Only the rider who logged a ride can change it. Looking it up through Current.user means
  # anyone else gets "not found" instead of someone else's ride.
  before_action :set_own_activity, only: %i[ edit update destroy ]

  def index
    @activities = Activity.with_photos_and_rider.newest_first
  end

  def show
    @activity = Activity.with_photos_and_rider.find(params[:id])
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

  def edit
  end

  def update
    if @activity.update(activity_params)
      redirect_to @activity, notice: "Ride updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @activity.destroy!
    redirect_to activities_path, notice: "Ride deleted.", status: :see_other
  end

  private
    def set_own_activity
      @activity = Current.user.activities.find(params[:id])
    end

    # route_coordinates arrives as a JSON string from the map; Activity#route_coordinates= parses it.
    def activity_params
      params.expect(activity: [ :title, :description, :started_at, :duration_hours, :duration_minutes, :duration_seconds,
                                :route_coordinates, new_photos: [], remove_photo_ids: [] ])
    end
end
