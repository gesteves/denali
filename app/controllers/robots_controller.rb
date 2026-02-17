class RobotsController < ApplicationController
  before_action :set_max_age
  def show
    @ai_agents = Rails.cache.fetch("known-agents", expires_in: 1.day) do
      known_agents = KnownAgents.new(access_token: ENV['KNOWN_AGENTS_ACCESS_TOKEN'])
      known_agents.robots_txt.presence
    end
    respond_to do |format|
      format.txt
    end
  end
end
