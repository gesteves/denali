class SlackController < ApplicationController

  def index
    expires_in 0, private: true, must_revalidate: true
    if params[:code].present? && params[:state] == session[:slack_state]
      session[:slack_state] = nil
      @webhook = save_webhook(params[:code])
      render 'success'
    else
      redirect_to slack_path if params[:state].present?
      @state = session[:slack_state] = SecureRandom.hex(10)
    end
  end

  private

  def save_webhook(code)
    response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['slack_client_id']}&client_secret=#{ENV['slack_client_secret']}&redirect_uri=#{slack_url}")
    token = JSON.parse(response.body)
    if token['ok']
      webhook = SlackIncomingWebhook.new(team_name: token['team_name'], team_id: token['team_id'], channel: token['incoming_webhook']['channel'], url: token['incoming_webhook']['url'], configuration_url: token['incoming_webhook']['configuration_url'], blog_id: @photoblog.id)
      webhook.save
      logger.info "[INFO] Slack incoming webhook created for the #{webhook.team_name} team in the #{webhook.channel} channel."
    else
      webhook = nil
    end
    webhook
  end
end
