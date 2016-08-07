class SlackController < ApplicationController
  before_action :no_cache
  before_action :check_if_user_has_visited

  def index
    if params[:code].present? && params[:state] == session[:slack_state]
      session[:slack_state] = nil
      @webhook = save_webhook(params[:code])
      render 'success'
    else
      @state = session[:slack_state] = SecureRandom.hex(10)
      @client_id = ENV['slack_client_id']
    end
  end

  private

  def save_webhook(code)
    token = get_access_token(code)
    if token['ok']
      webhook = SlackIncomingWebhook.new(team_name: token['team_name'], team_id: token['team_id'], channel: token['incoming_webhook']['channel'], url: token['incoming_webhook']['url'], configuration_url: token['incoming_webhook']['configuration_url'], blog_id: @photoblog.id)
      webhook.save
      logger.info "[INFO] Slack incoming webhook created for the #{webhook.team_name} team in the #{webhook.channel} channel."
    end
    webhook
  end

  def get_access_token(code)
    response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['slack_client_id']}&client_secret=#{ENV['slack_client_secret']}&redirect_uri=#{slack_url}")
    JSON.parse(response.body)
  end
end
