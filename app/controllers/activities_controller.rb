class ActivitiesController < ApplicationController
  def index
    @activities = Activity.newest_first
  end
end
