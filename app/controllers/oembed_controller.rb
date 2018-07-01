class OembedController < ApplicationController
  before_action :load_entry, :set_request_format
  before_action :set_entry_max_age, only: [:show]
  skip_before_action :verify_authenticity_token

  def show
    @url, @width, @height = get_photo(@entry, 1200, params[:maxwidth], params[:maxheight])
    @thumb_url, @thumb_width, @thumb_height = get_photo(@entry, 300, params[:maxwidth], params[:maxheight])
    if stale?(@entry, public: true)
      respond_to do |format|
        format.json
        format.xml
      end
    end
  end

  private

  def set_request_format
    request.format = params[:format] || 'json'
  end

  def load_entry
    url = Rails.application.routes.recognize_path(params[:url])
    if url[:controller] == 'entries' && url[:action] == 'show' && url[:id].present?
      @entry = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob]).published.find(url[:id])
    elsif url[:controller] == 'entries' && url[:action] == 'preview' && url[:preview_hash].present?
      @entry = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob]).where(preview_hash: url[:preview_hash]).limit(1).first
    else
      raise ActiveRecord::RecordNotFound
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

      url = entry.photos.first.url(w: width, h: height)
    end
    return url, width, height
  end
end
