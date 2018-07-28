class MapsController < ApplicationController
  before_action :set_max_age, only: [:index, :photos]
  before_action :set_entry_max_age, only: [:photo]
  before_action :set_map_link_headers, only: [:index]
  skip_before_action :verify_authenticity_token

  def index
    @hide_footer = true
    @minimal_header = true
  end

  def photos
    if stale?(@photoblog, public: true)
      respond_to do |format|
        format.json
      end
    end
  end

  def photo
    @photo = Photo.joins(:entry).where(photos: { id: params[:id] }, entries: { status: 'published' }).limit(1).first
    raise ActiveRecord::RecordNotFound if @photo.nil?
    respond_to do |format|
      format.json
    end
  end

  private
  def set_map_link_headers
    if request.format.html?
      add_preload_link_header(map_markers_url(format: 'json'), as: 'fetch', crossorigin: 'anonymous')
      add_preconnect_link_header('https://api.mapbox.com')
      add_preconnect_link_header('https://a.tiles.mapbox.com')
      add_preconnect_link_header('https://b.tiles.mapbox.com')
    end
  end
end
