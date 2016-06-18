class MapsController < ApplicationController
  layout false

  def index
    expires_in 24.hours, public: true
  end

  def photos
    @entries = @photoblog.entries.photo_entries.published.mapped.joins(:photos).includes(:photos).where('photos.latitude is not null AND photos.longitude is not null')
    expires_in 24.hours, public: true
    respond_to do |format|
      format.json
    end
  end
end
