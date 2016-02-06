class MapsController < ApplicationController
  layout false
  def index
  end

  def photos
    @entries = @photoblog.entries.includes(:photos).published
    expires_in 60.minutes, :public => true
    respond_to do |format|
      format.json
    end
  end
end
