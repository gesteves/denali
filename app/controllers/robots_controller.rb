class RobotsController < ApplicationController
  before_action :set_max_age
  def show
    @ai_agents = Rails.cache.fetch("dark-visitors", expires_in: 1.day) do
      dark_visitors = DarkVisitors.new(access_token: ENV['DARK_VISITORS_ACCESS_TOKEN'])
      dark_visitors.robots_txt.presence
    end
    respond_to do |format|
      format.txt
    end
  end
end
