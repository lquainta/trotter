class PagesController < ApplicationController
  def home
    @recent_activities = Activity.newest_first.limit(3)
  end
end
