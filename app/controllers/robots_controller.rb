class RobotsController < ApplicationController
  def show
    expires_in 24.hours, public: true
    @ai_agents = Rails.cache.fetch("dark-visitors", expires_in: 1.day) do
      dark_visitors = DarkVisitors.new(access_token: ENV['DARK_VISITORS_ACCESS_TOKEN'])
      dark_visitors.robots_txt.presence
    end
    respond_to do |format|
      format.txt
    end
  end
end
