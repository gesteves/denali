class MapsController < ApplicationController
  layout false
  before_action :check_if_user_has_visited, only: [:index]

  def index
    expires_in 24.hours, public: true
    fresh_when @photoblog, public: true
  end

  def photos
    expires_in 24.hours, public: true
    @entries = @photoblog.entries.mapped
    if stale?(@photoblog, public: true)
      respond_to do |format|
        format.json
      end
    end
  end
end
