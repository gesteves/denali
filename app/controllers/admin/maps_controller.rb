class Admin::MapsController < AdminController
  skip_before_action :no_cache, only: [:photos]

  def index
    @page_title = 'Map'
    @no_container = true
    respond_to do |format|
      format.html
    end
  end

  def photos
    fresh_when @photoblog
  end

  def photo
    @srcset = PHOTOS[:map][:srcset]
    @sizes = PHOTOS[:map][:sizes].join(', ')
    @photo = Photo.joins(:entry).merge(Entry.mapped).find_by(photos: { id: params[:id] })
    raise ActiveRecord::RecordNotFound if @photo.nil?
    respond_to do |format|
      format.json
    end
  end
end
