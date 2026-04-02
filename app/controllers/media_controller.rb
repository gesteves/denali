class MediaController < ApplicationController
  skip_before_action :verify_authenticity_token

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

    image_response = HTTParty.get(url)
    set_max_age
    send_data image_response.body, type: image_response.content_type, disposition: 'inline'
  end
end
