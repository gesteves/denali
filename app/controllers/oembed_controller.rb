class OembedController < ApplicationController
  before_action :load_entry, :set_request_format
  before_action :set_max_age
  skip_before_action :verify_authenticity_token
  after_action :set_cors_headers

  def show
    raise ActiveRecord::RecordNotFound unless @entry.photos_have_dimensions?

    response.etag = [@entry, @entry.updated_at]
    response.last_modified = @entry.updated_at
    return head(:not_modified) if request.fresh?(response)

    logger.tagged('oEmbed') { logger.info { "oEmbed requested for url: #{params[:url]}, maxwidth: #{params[:maxwidth] || 'none'}, maxheight: #{params[:maxheight] || 'none'}, format: #{request.format}" } }
    @url, @width, @height = get_photo(@entry, 1200, params[:maxwidth], params[:maxheight])
    @thumb_url, @thumb_width, @thumb_height = get_photo(@entry, 300, params[:maxwidth], params[:maxheight])
    respond_to do |format|
      format.json
      format.xml { render content_type: 'text/xml' }
    end
  end

  private

  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  def set_request_format
    request.format = params[:format] || 'json'
  end

  def load_entry
    @entry = Entry.find_by_url(url: params[:url])
    ActiveRecord::Associations::Preloader.new(
      records: [@entry],
      associations: [:photos, :user]
    ).call
  end

  def get_photo(entry, width = 1200, maxwidth, maxheight)
    if entry.is_photo?
      photo = entry.photos[0]
      height = photo.height_from_width(width)

      if maxwidth.present? && maxwidth.to_i < width
        width = maxwidth.to_i
        height = photo.height_from_width(width)
      end

      if maxheight.present? && maxheight.to_i < height
        height = maxheight.to_i
        width = photo.width_from_height(height)
      end

      url = photo.url(width: width, height: height)
    end
    return url, width, height
  end
end
