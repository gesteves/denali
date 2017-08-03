class RobotsController < ApplicationController
  def show
    expires_in 24.hours, public: true
    respond_to do |format|
      format.txt
    end
  end
end
