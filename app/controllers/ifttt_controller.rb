class IftttController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :domain_redirect

  def instagram
    if params[:token] != ENV['ifttt_webhook_token']
      render plain: 'No', status: 401
    else
      logger.tagged('IFTTT', 'WEBHOOK') { logger.info params[:created_at] }
      logger.tagged('IFTTT', 'WEBHOOK') { logger.info params[:source_url] }
      logger.tagged('IFTTT', 'WEBHOOK') { logger.info params[:url] }
      entry = Entry.published.first
      hashtags = entry.instagram_hashtags
      payload = {
        value1: hashtags
      }
      SlackJob.perform_later(text: hashtags)
      IftttWebhookJob.perform_later('instagram_tags', payload.to_json)
      render plain: 'OK'
    end
  end
end
