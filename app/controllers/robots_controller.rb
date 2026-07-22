class RobotsController < ApplicationController
  before_action :set_max_age
  def show
    respond_to do |format|
      format.txt
    end
  end
end
