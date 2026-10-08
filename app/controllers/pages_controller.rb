class PagesController < ApplicationController
  allow_unauthenticated_access

  def hello
    render layout: false
  end
end
