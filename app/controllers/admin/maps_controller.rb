class Admin::MapsController < AdminController
  before_action :set_map_link_headers, only: [:index]
  skip_before_action :verify_authenticity_token

  def index
    @page_title = 'Map'
    @no_container = true
    respond_to do |format|
      format.html
    end
  end

  def photos
    respond_to do |format|
      format.json
    end
  end

  def photo
    @srcset = PHOTOS[:map][:srcset]
    @sizes = PHOTOS[:map][:sizes].join(', ')
    @photo = Photo.joins(:entry).where(photos: { id: params[:id] }).limit(1).first
    raise ActiveRecord::RecordNotFound if @photo.nil?
    respond_to do |format|
      format.json
    end
  end

  private
  def set_map_link_headers
    if request.format.html?
      add_preload_link_header(admin_map_markers_url(format: 'json'), as: 'fetch', crossorigin: 'anonymous')
      add_preconnect_link_header('https://a.tiles.mapbox.com')
    end
  end
end
