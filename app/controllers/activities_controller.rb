class ActivitiesController < ApplicationController
  allow_unauthenticated_access

  def index
    @activities = Activity.includes(:user).newest_first
  end
end
