class Admin::SlackIncomingWebhooksController < AdminController
  def index
    @page = params[:page] || 1
    @webhooks = @photoblog.slack_incoming_webhooks.order('created_at DESC').page(@page).per(100)
    @page_title = 'Slack Incoming Webhooks'
  end
end
