class Admin::SlackIncomingWebhooksController < AdminController
  def index
    @page = params[:page] || 1
    @webhooks = @photoblog.slack_incoming_webhooks.order('created_at DESC').page(@page).per(100)
    @page_title = 'Slack Incoming Webhooks'
    @client_id = ENV['slack_client_id']
    @redirect_uri = admin_slack_url({ host: request.host_with_port })
    if params[:code].present?
      @webhook = save_webhook(params[:code])
      if @webhook.present?
        flash[:notice] = "A Slack webhook was added to the #{@webhook.channel} channel of #{@webhook.team_name}."
      else
        flash[:alert] = 'Welp, the Slack webhook couldn’t be saved.'
      end
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
    response = HTTParty.get("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['slack_client_id']}&client_secret=#{ENV['slack_client_secret']}&redirect_uri=#{admin_slack_url({ host: request.host_with_port })}")
    JSON.parse(response.body)
  end
end
