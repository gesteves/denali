class Admin::MapsController < AdminController
  skip_before_action :verify_authenticity_token

  def index
    if stale?(@photoblog)
      @page_title = 'Map'
      @no_container = true
      respond_to do |format|
        format.html
      end
    end
  end

  def photos
    if stale?(@photoblog)
      respond_to do |format|
        format.json
      end
    end
  end

  def photo
    if stale?(@photoblog)
      @srcset = PHOTOS[:map][:srcset]
      @sizes = PHOTOS[:map][:sizes].join(', ')
      @photo = Photo.joins(:entry).where(photos: { id: params[:id] }).limit(1).first
      raise ActiveRecord::RecordNotFound if @photo.nil?
      respond_to do |format|
        format.json
      end
    end
  end
end
