class MediaController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :no_cache

  STYLES = {
    'instagram' => :instagram_url,
    'instagram_story' => :instagram_story_url,
    'threads' => :threads_url
  }.freeze

  def show
    photo = Photo.find(params[:photo_id])
    style = STYLES[params[:style]]
    raise ActionController::RoutingError.new('Not Found') unless style

    url = if style == :instagram_story_url
      photo.instagram_story_url(crop: params[:crop] == 'true')
    else
      photo.send(style)
    end

    redirect_to url, allow_other_host: true
  end
end
