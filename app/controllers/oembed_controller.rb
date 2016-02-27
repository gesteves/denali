class OembedController < ApplicationController
  before_action :set_max_age, :load_entry, :set_request_format

  def show
    @url, @width, @height = get_photo(@entry, 1200, params[:maxwidth], params[:maxheight])
    @thumb_url, @thumb_width, @thumb_height = get_photo(@entry, 300, params[:maxwidth], params[:maxheight])
    respond_to do |format|
      format.json
      format.xml
    end
  end

  private

  def set_request_format
    request.format = params[:format] || 'json'
  end

  def load_entry
    url = Rails.application.routes.recognize_path(params[:url])
    if url[:controller] != 'entries' || url[:action] != 'show' || url[:id].nil?
      raise ActiveRecord::RecordNotFound
    else
      @entry = @photoblog.entries.includes(:photos, :user).published.find(url[:id])
    end
  end

  def get_photo(entry, width = 1200, maxwidth, maxheight)
    if entry.is_photo?
      height = entry.photos.first.height_from_width(width)

      if maxwidth.present? && maxwidth.to_i < width
        width = maxwidth.to_i
        height = entry.photos.first.height_from_width(width)
      end

      if maxheight.present? && maxheight.to_i < height
        height = maxheight.to_i
        width = entry.photos.first.width_from_height(height)
      end

      url = entry.photos.first.url(width: width, height: height)
    end
    return url, width, height
  end
end
