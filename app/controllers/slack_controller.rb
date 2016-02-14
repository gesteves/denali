class SlackController < ApplicationController
  before_action :domain_redirect

  def index
    expires_in 0, private: true, must_revalidate: true
    if params[:code].present?
      token = get_access_token(params[:code])
      if token['ok']
        @webhook = SlackIncomingWebhook.new(team_name: token['team_name'], team_id: token['team_id'], channel: token['incoming_webhook']['channel'], url: token['incoming_webhook']['url'], configuration_url: token['incoming_webhook']['configuration_url'], blog_id: @photoblog.id)
        @added = @webhook.save
      end
    end
  end

  private

  def get_access_token(code)
    response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['slack_client_id']}&client_secret=#{ENV['slack_client_secret']}&redirect_uri=#{slack_url}")
    JSON.parse(response.body)
  end
end
