class MapsController < ApplicationController
  layout false

  def index
    expires_in 24.hours, public: true
    fresh_when @photoblog, public: true
  end

  def photos
    expires_in 24.hours, public: true
    if stale?(@photoblog, public: true)
      respond_to do |format|
        format.json
      end
    end
  end

  def photo
    expires_in 24.hours, public: true
    @photo = Photo.joins(:entry).where(photos: { id: params[:id] }, entries: { status: 'published' }).limit(1).first
    if stale?(@photo, public: true)
      respond_to do |format|
        format.html { render layout: nil }
      end
    end
  end
end
