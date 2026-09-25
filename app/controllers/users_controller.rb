class UsersController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = User.find_by!(username: params[:username])
    @activities = @user.activities.includes(:user).with_attached_photos.order(started_at: :desc)
  end
end
