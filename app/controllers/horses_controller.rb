class HorsesController < ApplicationController
  allow_unauthenticated_access only: :show
  # Only a horse's owner can change it. Looking it up through Current.user means anyone else
  # gets "not found" instead of someone else's horse.
  before_action :set_own_horse, only: %i[ edit update destroy ]

  def show
    @horse = Horse.includes(:user, photo_attachment: :blob).find(params[:id])
    @workloads = { "This week" => @horse.workload(Time.current.all_week),
                   "This month" => @horse.workload(Time.current.all_month),
                   "All time" => @horse.workload }
    @weekly_distances = @horse.weekly_distances
    @activities = @horse.activities.with_photos_and_rider.newest_first
  end

  def new
    @horse = Current.user.horses.new
  end

  def create
    @horse = Current.user.horses.new(horse_params)

    if @horse.save
      redirect_to @horse, notice: "#{@horse.name} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @horse.update(horse_params)
      redirect_to @horse, notice: "#{@horse.name} updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @horse.destroy!
    redirect_to user_path(Current.user), notice: "#{@horse.name} deleted. Their rides are still in your profile.",
      status: :see_other
  end

  private
    def set_own_horse
      @horse = Current.user.horses.find(params[:id])
    end

    def horse_params
      params.expect(horse: [ :name, :breed, :color, :birth_year, :notes, :photo, :remove_photo ])
    end
end
