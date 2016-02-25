class OembedController < ApplicationController
  before_action :set_max_age

  def show
    url = Rails.application.routes.recognize_path(params[:url])
    if url[:controller] != 'entries' || url[:action] != 'show' || url[:id].nil?
      raise ActiveRecord::RecordNotFound
    else
      @entry = @photoblog.entries.includes(:photos, :user).published.find(url[:id])
      @url, @width, @height = get_photo_width(@entry, params[:maxwidth], params[:maxheight])

      request.format = params[:format] || 'json'
      respond_to do |format|
        format.json
        format.xml
      end
    end
  end

  private

  def get_photo_width(entry, maxwidth, maxheight)
    if entry.is_photo?
      width = maxwidth || 600
      url = entry.photos.first.url(width, maxheight)
      height = maxheight || ((entry.photos.first.height.to_f * width.to_f)/entry.photos.first.width.to_f).round
    end
    return url, width, height
  end
end
