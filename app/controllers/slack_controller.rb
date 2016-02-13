class SlackController < ApplicationController
  def index
    if params[:code].present? && params[:state] == session[:slack_state]
      session[:slack_state] = nil
      access_token = get_access_token(params[:code])
      if access_token['ok']
        @added = true
        @channel = access_token['incoming_webhook']['channel']
        @team = access_token['team_name']
      end
    else
      @state = session[:slack_state] = SecureRandom.hex(10)
    end
  end

  private

  def get_access_token(code)
    response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['slack_client_id']}&client_secret=#{ENV['slack_client_secret']}&redirect_uri=#{slack_url}")
    JSON.parse(response.body)
  end
end
