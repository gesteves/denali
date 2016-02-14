class Admin::SlackIncomingWebhooksController < AdminController
  def index
    @page = params[:page] || 1
    @webhooks = @photoblog.slack_incoming_webhooks.order('created_at DESC').page(@page).per(100)
    @page_title = 'Slack Incoming Webhooks'
  end

  def destroy
    webhook = SlackIncomingWebhook.find(params[:id])
    webhook.destroy
    respond_to do |format|
      flash[:notice] = 'The webhook was deleted!'
      format.html { redirect_to request.referrer || admin_slack_incoming_webhooks_path }
    end
  end
end
