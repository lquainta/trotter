class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @recent_activities = Activity.includes(:user).with_attached_photos.order(started_at: :desc).limit(3)
  end

  def hello
    render layout: false
  end
end
