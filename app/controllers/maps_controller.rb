class MapsController < ApplicationController
  layout false
  before_action :set_max_age, only: [:index]

  def index
  end

  def photos
    @entries = @photoblog.entries.photo_entries.published.joins(:photos).where('photos.latitude is not null AND photos.longitude is not null')
    expires_in 24.hours, :public => true
    respond_to do |format|
      format.json
    end
  end
end
