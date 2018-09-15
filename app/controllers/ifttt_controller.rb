class IftttController < ApplicationController
  skip_before_action :verify_authenticity_token

  def instagram
    if params[:token] != ENV['ifttt_webhook_token']
      render plain: 'No', status: 401
    else
      logger.tagged('IFTTT', 'WEBHOOK') { logger.info params[:created_at] }
      logger.tagged('IFTTT', 'WEBHOOK') { logger.info params[:source_url] }
      logger.tagged('IFTTT', 'WEBHOOK') { logger.info params[:url] }
      entry = Entry.published.first
      payload = {
        value1: entry.plain_title,
        value2: share_admin_entry_url(entry, host: "#{ENV['HEROKU_APP_NAME']}.herokuapp.com", protocol: 'https'),
        value3: entry.photos.first.url(w: 1200, fm: 'jpg')
      }
      IftttWebhookJob.perform_later('instagram_tags', payload.to_json)
      render plain: 'OK'
    end
  end
end
