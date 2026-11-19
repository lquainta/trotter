# /search: a GET form, so every search has a shareable URL such as /search?q=foothills&min_distance=1&sort=longest.
class SearchesController < ApplicationController
  allow_unauthenticated_access

  def show
    @search = ActivitySearch.new(search_params, unit: helpers.current_distance_unit)
    @horses = Horse.includes(:user).by_name
  end

  private
    def search_params
      params.permit(:q, :rider, :horse_id, :min_distance, :max_distance, :from, :to, :photos, :sort, :page)
    end
end
