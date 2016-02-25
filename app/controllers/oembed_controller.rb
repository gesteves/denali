class OembedController < ApplicationController
  before_action :set_max_age

  def show
    url = Rails.application.routes.recognize_path(params[:url])
    if url[:controller] != 'entries' || url[:action] != 'show' || url[:id].nil?
      raise ActiveRecord::RecordNotFound
    else
      @entry = @photoblog.entries.includes(:photos, :user).published.find(url[:id])
      @url, @width, @height = get_photo(@entry, 1200, params[:maxwidth], params[:maxheight])
      @thumb_url, @thumb_width, @thumb_height = get_photo(@entry, 150, params[:maxwidth], params[:maxheight])

      request.format = params[:format] || 'json'
      respond_to do |format|
        format.json
        format.xml
      end
    end
  end

  private

  def get_photo(entry, default_width = 1200, maxwidth, maxheight)
    if entry.is_photo?
      width = maxwidth.present? ? [maxwidth.to_i, default_width].min : default_width
      url = entry.photos.first.url(width, maxheight)
      default_height = ((entry.photos.first.height.to_f * width.to_f)/entry.photos.first.width.to_f).round
      height = maxheight.present? ? [maxheight.to_i, default_height].min : default_height
    end
    return url, width, height
  end
end
