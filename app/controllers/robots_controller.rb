class RobotsController < ApplicationController
  def show
    expires_in 1.year, public: true
    respond_to do |format|
      format.txt
    end
  end
end
