class MapsController < ApplicationController
  before_action :set_max_age, only: [:index, :photos, :photo]
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
    if stale?(@photo, public: true)
      respond_to do |format|
        format.json
      end
    end
  end

  private
  def set_map_link_headers
    if request.format.html?
      add_preload_link_header(ActionController::Base.helpers.asset_path('vendor/map.js'), as: 'script')
      add_preload_link_header(map_markers_url(format: 'json'), as: 'fetch')
      add_preconnect_link_header('https://api.mapbox.com')
      add_preconnect_link_header('https://a.tiles.mapbox.com')
      add_preconnect_link_header('https://b.tiles.mapbox.com')
    end
  end
end
