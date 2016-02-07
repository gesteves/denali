class MapsController < ApplicationController
  layout false
  def index
  end

  def photos
    @entries = @photoblog.entries.photo_entries.includes(:photos).published
    expires_in 24.hours, :public => true
    respond_to do |format|
      format.json
    end
  end
end
