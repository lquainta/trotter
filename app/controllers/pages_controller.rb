class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @recent_activities = Activity.includes(:user).newest_first.limit(3)
  end
end
