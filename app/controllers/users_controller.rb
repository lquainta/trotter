class UsersController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = User.find_by!(username: params[:username])
    @activities = @user.activities.with_photos_and_rider.newest_first
  end
end
