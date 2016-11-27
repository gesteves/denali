class MapsController < ApplicationController
  layout false

  def index
    expires_in 24.hours, public: true
    fresh_when @photoblog, public: true
  end

  def photos
    expires_in 24.hours, public: true
    if stale?(@photoblog, public: true)
      @entries = Rails.cache.fetch("map/query/#{@photoblog.id}/#{@photoblog.updated_at}") do
        @photoblog.entries.mapped
      end
      respond_to do |format|
        format.json
      end
    end
  end
end
