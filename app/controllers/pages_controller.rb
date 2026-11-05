class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @recent_activities = Activity.with_photos_and_rider.newest_first.limit(3)
  end
end
