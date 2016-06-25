class MapsController < ApplicationController
  layout false

  def index
    expires_in 24.hours, public: true
    fresh_when @photoblog
  end

  def photos
    expires_in 24.hours, public: true
    if stale?(@photoblog)
      respond_to do |format|
        format.json
      end
    end
  end
end
