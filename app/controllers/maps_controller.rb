class MapsController < ApplicationController
  layout false

  def index
    expires_in 24.hours, public: true
  end

  def photos
    expires_in 24.hours, public: true
    respond_to do |format|
      format.json
    end
  end
end
